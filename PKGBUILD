# Maintainer: mesaprotector < arcanapluvia at gmail dot com >
pkgname=sudo-comment
pkgver=
pkgrel=
pkgdesc='Prompt for comment after certain commands run as root'
arch=('any')
url='https://github.com/mesaprotector/sudo-comment'
license=('Apache-2.0')
depends=(
	'ttyecho-git'
	'entr'
 	'sudo'
)
source=($url/archive/v$pkgver/$pkgname-v$pkgver.tar.gz)
sha256sums=()

package() {
	cd "${srcdir}/${pkgname}-${pkgver}"
	install -Dm0755 addcomment "${pkgdir}/usr/bin/addcomment"
	install -Dm0755 findcomment "${pkgdir}/usr/bin/findcomment"
	install -Dm0755 waitcomment.sh "${pkgdir}/usr/lib/waitcomment.sh" 
	install -Dm0644 sudo-comment.conf "${pkgdir}/etc/sudo-comment.conf"
	install -Dm0644 sudo-comment.service "${pkgdir}/usr/lib/systemd/system/sudo-comment.service"
	install -Dm0644 LICENSE "${pkgdir}/usr/share/doc/${pkgname}/LICENSE"
	install -Dm0644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
}
