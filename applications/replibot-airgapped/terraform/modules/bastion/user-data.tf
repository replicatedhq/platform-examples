output "rendered_template" {
  value = templatefile("${path.module}/init.tpl", {
    airgap_download_script     = "${var.airgap_download_script}"
  })
}
