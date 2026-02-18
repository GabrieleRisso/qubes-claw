Name:           qubes-openclaw-policy
Version:        1.0.0
Release:        1%{?dist}
Summary:        Qubes OS dom0 ConnectTCP policy for OpenClaw
License:        MIT
URL:            https://github.com/GabrieleRisso/qubes-claw
BuildArch:      noarch

%description
Dom0 policy file that allows the openclaw-admin VM to connect to the
OpenClaw Cursor proxy and gateway via qubes.ConnectTCP.

%install
mkdir -p %{buildroot}%{_sysconfdir}/qubes/policy.d

install -m 0644 %{_sourcedir}/50-openclaw.policy %{buildroot}%{_sysconfdir}/qubes/policy.d/

%files
%config(noreplace) %{_sysconfdir}/qubes/policy.d/50-openclaw.policy
