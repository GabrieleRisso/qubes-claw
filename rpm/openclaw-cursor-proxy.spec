Name:           openclaw-cursor-proxy
Version:        1.0.0
Release:        1%{?dist}
Summary:        OpenClaw Cursor proxy for Qubes OS
License:        MIT
URL:            https://github.com/GabrieleRisso/openclaw-cursor

%description
HTTP proxy that enables OpenClaw to use Cursor Pro models via cursor-agent.
Translates OpenAI-compatible API requests to cursor-agent stream-json format.
Designed for Qubes OS VM isolation with qubes.ConnectTCP cross-VM access.
Services are Qubes-managed: toggle with qvm-service from dom0.

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/lib/systemd/system
mkdir -p %{buildroot}/etc/openclaw
mkdir -p %{buildroot}/usr/share/openclaw-cursor/scripts

install -m 0755 %{_sourcedir}/openclaw-cursor %{buildroot}/usr/bin/openclaw-cursor
install -m 0755 %{_sourcedir}/openclaw-ctl %{buildroot}/usr/bin/openclaw-ctl
install -m 0644 %{_sourcedir}/qubes-openclaw-proxy.service %{buildroot}/usr/lib/systemd/system/
install -m 0644 %{_sourcedir}/qubes-openclaw-gateway.service %{buildroot}/usr/lib/systemd/system/
install -m 0644 %{_sourcedir}/qubes-openclaw-watchdog.service %{buildroot}/usr/lib/systemd/system/
install -m 0644 %{_sourcedir}/cursor-proxy.json %{buildroot}/etc/openclaw/
install -m 0755 %{_sourcedir}/setup-vm.sh %{buildroot}/usr/share/openclaw-cursor/scripts/
install -m 0755 %{_sourcedir}/monitor-dashboard.sh %{buildroot}/usr/share/openclaw-cursor/scripts/
install -m 0755 %{_sourcedir}/openclaw-watchdog.sh %{buildroot}/usr/share/openclaw-cursor/scripts/
install -m 0755 %{_sourcedir}/openclaw-wait-ready.sh %{buildroot}/usr/share/openclaw-cursor/scripts/
install -m 0755 %{_sourcedir}/harden.sh %{buildroot}/usr/share/openclaw-cursor/scripts/

%post
systemctl daemon-reload
systemctl enable qubes-openclaw-proxy qubes-openclaw-gateway qubes-openclaw-watchdog 2>/dev/null || true
echo ""
echo "OpenClaw installed. Enable from dom0:"
echo "  qvm-service <vm> openclaw-proxy on"
echo "  qvm-service <vm> openclaw-gateway on"
echo "  qvm-service <vm> openclaw-watchdog on"
echo ""
echo "Then restart the VM, or create the flags manually:"
echo "  sudo touch /var/run/qubes-service/openclaw-{proxy,gateway,watchdog}"
echo "  sudo systemctl start qubes-openclaw-proxy qubes-openclaw-gateway"
echo ""
echo "View status: openclaw-ctl status"
echo "View logs:   openclaw-ctl logs [proxy|gateway|watchdog]"

%preun
systemctl disable --now qubes-openclaw-proxy qubes-openclaw-gateway qubes-openclaw-watchdog 2>/dev/null || true
systemctl daemon-reload

%files
/usr/bin/openclaw-cursor
/usr/bin/openclaw-ctl
/usr/lib/systemd/system/qubes-openclaw-proxy.service
/usr/lib/systemd/system/qubes-openclaw-gateway.service
/usr/lib/systemd/system/qubes-openclaw-watchdog.service
%config(noreplace) /etc/openclaw/cursor-proxy.json
/usr/share/openclaw-cursor/
