Name:           openclaw-cursor-client
Version:        1.0.0
Release:        1%{?dist}
Summary:        OpenClaw Cursor admin client for Qubes OS
License:        MIT
URL:            https://github.com/GabrieleRisso/qubes-claw
BuildArch:      noarch
Requires:       qubes-core-agent-networking
Requires:       curl
Requires:       firefox

%description
Client scripts and desktop shortcuts for connecting to the OpenClaw
Cursor proxy from an admin VM via qubes.ConnectTCP.
Service is Qubes-managed: toggle with qvm-service openclaw-tunnels from dom0.

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}/usr/lib/systemd/system
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_sysconfdir}/xdg/autostart

install -m 0755 %{_sourcedir}/openclaw-connect.sh %{buildroot}%{_bindir}/openclaw-connect
install -m 0755 %{_sourcedir}/openclaw-tunnel-daemon.sh %{buildroot}%{_bindir}/openclaw-tunnel-daemon
install -m 0755 %{_sourcedir}/openclaw-ctl-client %{buildroot}%{_bindir}/openclaw-ctl
install -m 0755 %{_sourcedir}/test-connecttcp.sh %{buildroot}%{_bindir}/openclaw-test
install -m 0644 %{_sourcedir}/qubes-openclaw-tunnels.service %{buildroot}/usr/lib/systemd/system/
install -m 0644 %{_sourcedir}/openclaw-dashboard.desktop %{buildroot}%{_datadir}/applications/
install -m 0644 %{_sourcedir}/openclaw-tunnels.desktop %{buildroot}%{_sysconfdir}/xdg/autostart/

%post
systemctl daemon-reload
systemctl enable qubes-openclaw-tunnels 2>/dev/null || true
echo ""
echo "OpenClaw client installed. Enable from dom0:"
echo "  qvm-service <vm> openclaw-tunnels on"
echo ""
echo "View status: openclaw-ctl status"

%preun
systemctl disable --now qubes-openclaw-tunnels 2>/dev/null || true
systemctl daemon-reload

%files
%{_bindir}/openclaw-connect
%{_bindir}/openclaw-tunnel-daemon
%{_bindir}/openclaw-ctl
%{_bindir}/openclaw-test
/usr/lib/systemd/system/qubes-openclaw-tunnels.service
%{_datadir}/applications/openclaw-dashboard.desktop
%{_sysconfdir}/xdg/autostart/openclaw-tunnels.desktop
