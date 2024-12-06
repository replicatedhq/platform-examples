package daemon

func (d *Daemon) addRoutesV1() error {
	addRoutersWriteV1(d.unauthedGroup)

	return nil
}
