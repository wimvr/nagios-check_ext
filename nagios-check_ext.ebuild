# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Nagios plugin to check if the next full filesystem check is coming soon."
HOMEPAGE="https://github.com/wimvr/nagios-check_ext"
SRC_URI="https://github.com/wimvr/${PN}/archive/${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64 x86"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
	exeinto /usr/lib64/nagios/plugins/
	doexe check_ext_disks.sh
	insinto /etc/sudoers.d/
	newins sudoers nagios_check_ext_disks
	dodoc README
}

