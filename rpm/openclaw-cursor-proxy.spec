%define _unitdir /usr/lib/systemd/user

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

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}/etc/openclaw
mkdir -p %{buildroot}/usr/share/openclaw-cursor/scripts

install -m 0755 %{_sourcedir}/openclaw-cursor %{buildroot}/usr/bin/openclaw-cursor
install -m 0644 %{_sourcedir}/openclaw-cursor-proxy.service %{buildroot}%{_unitdir}/
install -m 0644 %{_sourcedir}/openclaw-gateway.service %{buildroot}%{_unitdir}/
install -m 0644 %{_sourcedir}/cursor-proxy.json %{buildroot}/etc/openclaw/
install -m 0755 %{_sourcedir}/setup-vm.sh %{buildroot}/usr/share/openclaw-cursor/scripts/
install -m 0755 %{_sourcedir}/monitor-dashboard.sh %{buildroot}/usr/share/openclaw-cursor/scripts/

%post
echo "Run 'openclaw-cursor login' to authenticate, then enable services:"
echo "  systemctl --user enable --now openclaw-cursor-proxy openclaw-gateway"

%preun
systemctl --user disable --now openclaw-cursor-proxy openclaw-gateway 2>/dev/null || true

%files
/usr/bin/openclaw-cursor
%{_unitdir}/openclaw-cursor-proxy.service
%{_unitdir}/openclaw-gateway.service
%config(noreplace) /etc/openclaw/cursor-proxy.json
/usr/share/openclaw-cursor/
