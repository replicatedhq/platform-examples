# Contributing 

Anyone in the Replicated community is welcome to contribute examples to this
repository. Any and all PRs are welcome and will be reviewed by a member of the
Replicated team.

## Patterns vs. Applications

When making a contribution, you should determine whether your example is best
shared as a pattern or an application. Patterns demonstrate a single reusable
solution to a problem, while applications show multiple reusable solutions in
the context of a broader application. During the review process, we may ask
that your show your pattern in the context of a larger application, or extract
one or more patterns from your application example. 

Even a very simple pattern can (and should) be packaged as a deployable
application, but the goal is different. The goal of a pattern is to show a
single common problem and it's solution. An example is pattern is "Specifying
TLS Certificates for a KOTS Application". The main goal of this pattern is to
show the best practices for collecting the TLS certificate, private key, and CA
chain as configuration options in KOTS. The best way to show the pattern is to
bundle it as a simple application that then uses the collected certificates.
The implemenations for this could present a static README page with NGINX
secured using that certificate.

