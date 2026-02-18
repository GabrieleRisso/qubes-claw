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

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_sysconfdir}/xdg/autostart

install -m 0755 %{_sourcedir}/openclaw-connect.sh %{buildroot}%{_bindir}/openclaw-connect
install -m 0755 %{_sourcedir}/test-connecttcp.sh %{buildroot}%{_bindir}/openclaw-test
install -m 0644 %{_sourcedir}/openclaw-dashboard.desktop %{buildroot}%{_datadir}/applications/
install -m 0644 %{_sourcedir}/openclaw-tunnels.desktop %{buildroot}%{_sysconfdir}/xdg/autostart/

%files
%{_bindir}/openclaw-connect
%{_bindir}/openclaw-test
%{_datadir}/applications/openclaw-dashboard.desktop
%{_sysconfdir}/xdg/autostart/openclaw-tunnels.desktop
