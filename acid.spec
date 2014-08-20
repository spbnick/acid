Name:       acid
Version:    1
Release:    1%{?rev}%{?dist}
Summary:    Another CI dispatcher

License:    GPLv2+
BuildArch:  noarch
Source:     %{name}-%{version}.tar.gz

Requires:   git
Requires:   bash
Requires:   thud

%description

%prep
%setup -q

%build
%configure
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}

%files
%doc %{_datadir}/doc/%{name}/README.md
%{_bindir}/acid-*
%{_datadir}/%{name}

%changelog
