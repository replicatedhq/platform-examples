# Verifying Image Signatures with Replicated Preflight Checks

A question came up this morning about checking image signatures when distributing software through the Replicated Platform. This is something I've tackled before with a solution I'm particularly fond of.

While end customers might reach for a Kyverno policy to enforce image signature verification, Kyverno isn't something you typically ship with commercial software. The real insight here is that for software distribution, what matters most is verifying signatures at the critical moments: installation and upgrade time. This calls for a more lightweight approach, and preflight checks fit perfectly.

## Verification with Known Keys

The preflight check is pretty straightforward, differing depending on how you sign your images. For key-based signing, the approach centers on embedding your public key directly in the check and running cosign verification against your target images.

The preflight runs a pod containing cosign and your public key, then attempts verification against the specified images. If verification succeeds, you get a clear "verified" output that the analyzer can parse for a passing result. The security context ensures the validation runs with minimal privileges—no root access, read-only filesystem, and dropped capabilities.

```yaml
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: cosign-signature-check
spec:
  collectors:
    - runPod:
        name: image-signature
        namespace: default
        podSpec:
          containers:
            - name: validator
              image: nixery.dev/shell/coreutils/openssl/jq/cosign
              imagePullPolicy: IfNotPresent
              env:
                - name: COSIGN_KEY
                  value: |
                    # Replace with your own signing key
                    -----BEGIN PUBLIC KEY-----
                    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETPIGSVFx2AgTBcr+bZ8DNAMql4fW
                    kxjqKKsbcy9uQw7HjhsqPnZniQNAUwl1wDkUQ3Y7w6zK4OV9k38DT9bmow==
                    -----END PUBLIC KEY-----
              command:
                - bash
                - -c
                - |
                  set -x
                  echo "${COSIGN_KEY}" > /cosign-keys/cosign.pub
                  if cosign verify --key /cosign-keys/cosign.pub $0 $@ ; then
                    echo "verified"
                  else
                    echo "failed"
                  fi
              args:
                - ttl.sh/shell:1h
                - ttl.sh/cosign:1h
              resources:
                limits:
                  cpu: 500m
                  memory: 256Mi
                requests:
                  cpu: 100m
                  memory: 64Mi
              securityContext:
                allowPrivilegeEscalation: false
                privileged: false
                readOnlyRootFilesystem: true
                runAsNonRoot: true
                runAsUser: 65534
                capabilities:
                  drop:
                    - ALL
              volumeMounts:
                - name: sigstore
                  mountPath: /.sigstore
                  readOnly: false
                - name: cosign-key
                  mountPath: /cosign-keys
                  readOnly: false
          volumes:
            - name: sigstore
              emptyDir: {}
            - name: cosign-key
              emptyDir: {}
  analyzers:
    - textAnalyze:
        checkName: Image Signature Verification
        fileName: image-signature/image-signature.log
        regex: 'verified'
        outcomes:
          - pass:
              when: "true"
              message: Images signed by the expected signature
          - fail:
              when: "false"
              message: Images are not signed by the expected signature
```

## Keyless Signing Takes a Different Path

If you're using keyless signing, you don't have a known key to validate against. Instead, you're verifying against identity certificates tied to OIDC providers. We can't specify a key, so we specify the exact identity and issuer used during signing.

The preflight adapts by replacing the embedded key with environment variables that define the expected signing identity. The cosign command switches from key-based verification to certificate identity verification, checking both the signer's identity and the OIDC issuer that authenticated them.

```yaml
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: cosign-keyless-signature-check
spec:
  collectors:
    - runPod:
        name: image-signature
        namespace: default
        podSpec:
          containers:
            - name: validator
              image: nixery.dev/shell/coreutils/openssl/jq/cosign
              imagePullPolicy: IfNotPresent
              env:
                - name: COSIGN_CERTIFICATE_IDENTITY
                  value: "your-identity@example.com"
                - name: COSIGN_CERTIFICATE_OIDC_ISSUER
                  value: "https://github.com/login/oauth"
              command:
                - bash
                - -c
                - |
                  set -x
                  if cosign verify \
                    --certificate-identity="${COSIGN_CERTIFICATE_IDENTITY}" \
                    --certificate-oidc-issuer="${COSIGN_CERTIFICATE_OIDC_ISSUER}" \
                    $0 $@ ; then
                    echo "verified"
                  else
                    echo "failed"
                  fi
              args:
                - ttl.sh/shell:1h
                - ttl.sh/cosign:1h
              resources:
                limits:
                  cpu: 500m
                  memory: 256Mi
                requests:
                  cpu: 100m
                  memory: 64Mi
              securityContext:
                allowPrivilegeEscalation: false
                privileged: false
                readOnlyRootFilesystem: true
                runAsNonRoot: true
                runAsUser: 65534
                capabilities:
                  drop:
                    - ALL
              volumeMounts:
                - name: sigstore
                  mountPath: /.sigstore
                  readOnly: false
          volumes:
            - name: sigstore
              emptyDir: {}
  analyzers:
    - textAnalyze:
        checkName: Image Signature Verification
        fileName: image-signature/image-signature.log
        regex: 'verified'
        outcomes:
          - pass:
              when: "true"
              message: Images signed by the expected keyless signature
          - fail:
              when: "false"
              message: Images are not signed by the expected keyless signature
```

## Air-gapped Environments Need Special Consideration

As usual, air-gapped deployments introduce their own constraints. Keyless signing becomes impractical since you can't reach external OIDC providers for identity validation. This means you should sign your image with a known key. You'll also need to include the signatures themselves in your airgap bundle by adding them as [additional images in your Replicated configuration](https://docs.replicated.com/vendor/operator-defining-additional-images).

## Why I Use This Approach

The approach feel elegant in its timing and simplicity. Rather than running continuous policy enforcement, these preflight checks activate precisely when signature verification matters most. Customers get immediate, actionable feedback about image integrity without deploying or managing policy engines in their clusters.

This solution adapts to different signing strategies while integrating seamlessly with your existing preflight checks. Whether you choose keyless signing for its CI/CD advantages or key-based signing for tighter organizational control, you're delivering the security assurance customers need exactly when they need it. That's the kind of lightweight, targeted approach that works well in commercial software distribution.
