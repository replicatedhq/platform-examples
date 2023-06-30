# Specifying TLS certificates for a Replicated KOTS application

Most applications are delivered over a connection secured with TLS. When you
distribute your application to customers, they will usually need to provide
their own TLS certificates for the application to use. KOTS provides a way to
collect these using the KOTS configuiration screen.

This pattern is shows [an example in the Replicated
documentation](https://docs.replicated.com/reference/custom-resource-config#file)
in the context of a very simple application that services a static web page
using the provided certificates.
