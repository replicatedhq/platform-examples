#!/bin/bash

# Enable bash completion
source /etc/bash_completion

# kubectl completion
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k

# helm completion
source <(helm completion bash)

# task completion
source <(task --completion bash)

# helmfile completion
source <(helmfile completion bash)

# replicated completion
source <(replicated completion bash)

# gcloud completion
source /usr/share/google-cloud-sdk/completion.bash.inc
