# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit dart-pub

DESCRIPTION="Flutter SDK (prebuilt), for building Flutter applications from source"
HOMEPAGE="https://flutter.dev/"

# flutter refuses every command but --version until flutter_tools' own packages
# are resolved, so they ship with the SDK. Regenerate with pubspec2ebuild.py on
# packages/flutter_tools/pubspec.lock.
PUB_HOSTED=(
	"_fe_analyzer_shared 74.0.0 f6dbf021f4b214d85c79822912c5fcd142a2c4869f01222ad371bc51f9f1c356"
	"analyzer 6.9.0 f7e8caf82f2d3190881d81012606effdf8a38e6c1ab9e30947149733065f817c"
	"archive 3.6.1 cb6a278ef2dbb298455e1a713bda08524a175630ec643a242c399c932a0a1f7d"
	"args 2.5.0 7cf60b9f0cc88203c5a190b4cd62a99feea42759a7fa695010eb5de1c0b2252a"
	"async 2.11.0 947bfcf187f74dbc5e146c9eb9c0f10c9f8b30743e341481c1e2ed3ecc18c20c"
	"boolean_selector 2.1.1 6cfb5af12253eaf2b368f07bacc5a80d1301a071c73360d746b7f2e32d762c66"
	"browser_launcher 1.1.2 54a2da4d152c34760b87cbd4a9fe8a563379487e57bfcd1b387be394dfa91734"
	"built_collection 5.1.1 376e3dd27b51ea877c28d525560790aee2e6fbb5f20e2f85d5081027d94e2100"
	"built_value 8.9.2 c7913a9737ee4007efedaffc968c049fd0f3d0e49109e778edc10de9426005cb"
	"checked_yaml 2.0.3 feb6bed21949061731a7a75fc5d2aa727cf160b91af9a3e464c5e3a32e28b5ff"
	"cli_config 0.2.0 ac20a183a07002b700f0c25e61b7ee46b23c309d76ab7b7640a028f18e4d99ec"
	"clock 1.1.1 cb6d7f03e1de671e34607e909a7213e31d7752be4fb66a86d29fe1eb14bfb5cf"
	"collection 1.19.0 a1ace0a119f20aabc852d165077c036cd864315bd99b7eaa10a60100341941bf"
	"completion 1.0.1 f11b7a628e6c42b9edc9b0bc3aa490e2d930397546d2f794e8e1325909d11c60"
	"convert 3.1.1 0f08b14755d163f6e2134cb58222dd25ea2a2ee8a195e53983d57c075324d592"
	"coverage 1.9.2 c1fb2dce3c0085f39dc72668e85f8e0210ec7de05345821ff58530567df345a5"
	"crypto 3.0.5 ec30d999af904f33454ba22ed9a86162b35e52b44ac4807d1d93c288041d7d27"
	"csslib 1.0.0 706b5707578e0c1b4b7550f64078f0a0f19dec3f50a178ffae7006b0a9ca58fb"
	"dap 1.3.0 c0e53b52c9529d901329045afc4c5acb04304a28acde4b54ab0a08a93da546aa"
	"dds 4.2.7 c90723eb1f1402429c57f717550ce5af80288d74a27c45ccbe754a0e3e038f95"
	"dds_service_extensions 2.0.0 390ae1d0128bb43ffe11f8e3c6cd3a481c1920492d1026883d379cee50bdf1a2"
	"devtools_shared 10.0.2 72369878105eccd563547afbad97407a2431b96bd4c04a1d6da75cb068437f50"
	"dtd 2.3.0 6e4e508c0d03e12e2c96f21faa0e5acc191f9431ecd02adb8daee64dbfae6b86"
	"dwds 24.1.0 d0cf9d18511df6b397c40527f3fd8ddb47b7efcc501e703dd94f13cabaf82ffc"
	"extension_discovery 2.1.0 de1fce715ab013cdfb00befc3bdf0914bea5e409c3a567b7f8f144bc061611a7"
	"fake_async 1.3.1 511392330127add0b769b75a987850d136345d9227c6b94c96a04cf4a391bf78"
	"ffi 2.1.3 16ed7b077ef01ad6170a3d0c57caa4a112a38d7a2ed5602e0aca9ca6f3d98da6"
	"file 7.0.0 5fc22d7c25582e38ad9a8515372cd9a93834027aacf1801cf01164dac0ffa08c"
	"file_testing 3.0.0 0aaadb4025bd350403f4308ad6c4cea953278d9407814b8342558e4946840fb5"
	"fixnum 1.1.0 25517a4deb0c03aa0f32fd12db525856438902d9c16536311e76cdc57b31d7d1"
	"flutter_template_images 4.2.0 fd3e55af73c577b9e3f88d4080d3e366cb5c8ef3fbd50b94dfeca56bb0235df6"
	"frontend_server_client 4.0.0 f64a0333a82f30b0cca061bc3d143813a486dc086b574bfb233b7c1372427694"
	"glob 2.1.2 0e7014b3b7d4dac1ca4d6114f82bf1782ee86745b9b42a92c9289c23d8a0ab63"
	"graphs 2.3.2 741bbf84165310a68ff28fe9e727332eef1407342fca52759cb21ad8177bb8d0"
	"html 0.15.4 3a7812d5bcd2894edf53dfaf8cd640876cf6cef50a8f238745c8b8120ea74d3a"
	"http 1.2.2 b9c29a161230ee03d3ccf545097fccd9b87a5264228c5d348202e0f0c28f9010"
	"http_multi_server 3.2.1 97486f20f9c2f7be8f514851703d0119c3596d14ea63227af6f7a481ef2b2f8b"
	"http_parser 4.1.0 40f592dd352890c3b60fec1b68e786cefb9603e05ff303dbc4dda49b304ecdf4"
	"intl 0.19.0 d6f56758b7d3014a48af9701c085700aac781a92a87a62b1333b46d8879661cf"
	"io 1.0.4 2ec25704aba361659e10e3e5f5d672068d332fc8ac516421d483a11e5cbd061e"
	"js 0.7.1 c1b2e9b5ea78c45e1a0788d29606ba27dc5f71f019f32ca5140f61ef071838cf"
	"json_annotation 4.9.0 1ce844379ca14835a50d2f019a3099f419082cfdd231cd86a142af94dd5c6bb1"
	"json_rpc_2 3.0.2 5e469bffa23899edacb7b22787780068d650b106a21c76db3c49218ab7ca447e"
	"logging 1.2.0 623a88c9594aa774443aa3eb2d41807a48486b5613e67599fb4c41c0ad47c340"
	"macros 0.1.3-main.0 1d9e801cd66f7ea3663c45fc708450db1fa57f988142c64289142c9b7ee80656"
	"matcher 0.12.16+1 d2323aa2060500f906aa31a895b4030b6da3ebdcc5619d14ce1aada65cd161cb"
	"meta 1.15.0 bdb68674043280c3428e9ec998512fb681678676b3c54e773629ffe74419f8c7"
	"mime 1.0.6 801fd0b26f14a4a58ccb09d5892c3fbdeff209594300a542492cf13fba9d247a"
	"multicast_dns 0.3.2+7 982c4cc4cda5f98dd477bddfd623e8e4bd1014e7dbf9e7b05052e14a5b550b99"
	"mustache_template 2.0.0 a46e26f91445bfb0b60519be280555b06792460b27b19e2b19ad5b9740df5d1c"
	"native_assets_builder 0.8.3 ad76e66cc1ca7aa922d682651aee2663cd80e6ba483a346d13a8c40f604ebfd9"
	"native_assets_cli 0.8.0 db902509468ec2a6c6d11fa9ce02805ede280e8dbfb5f0014ef3de8483cadfce"
	"native_stack_traces 0.6.0 8ba566c10ea781491c203876b04b9bdcf19dfbe17b9e486869f20eaae0ee470f"
	"node_preamble 2.0.2 6e7eac89047ab8a8d26cf16127b5ed26de65209847630400f9aefd7cd5c730db"
	"package_config 2.1.0 1c5b77ccc91e4823a5af61ee74e6b972db1ef98c2ff5a18d3161c982a55448bd"
	"path 1.9.0 087ce49c3f0dc39180befefc60fdb4acd8f8620e5682fe2476afd0b3688bb4af"
	"petitparser 6.0.2 c15605cd28af66339f8eb6fbe0e541bfe2d1b72d5825efc6598f3e0a31b9ad27"
	"platform 3.1.5 9b71283fc13df574056616011fb138fd3b793ea47cc509c189a6c3fa5f8a1a65"
	"pool 1.5.1 20fe868b6314b322ea036ba325e6fc0711a22948856475e2c2b6306e8ab39c2a"
	"process 5.0.2 21e54fd2faf1b5bdd5102afd25012184a6793927648ea81eea80552ac9405b32"
	"pub_semver 2.1.4 40d3ab1bbd474c4c2328c91e3a7df8c6dd629b79ece4c4bd04bee496a224fb0c"
	"pubspec_parse 1.3.0 c799b721d79eb6ee6fa56f00c04b472dcd44a30d258fac2174a6ec57302678f8"
	"shelf 1.4.2 e7dd780a7ffb623c57850b33f43309312fc863fb6aa3d276a754bb299839ef12"
	"shelf_packages_handler 3.0.2 89f967eca29607c933ba9571d838be31d67f53f6e4ee15147d5dc2934fee1b1e"
	"shelf_proxy 1.0.4 a71d2307f4393211930c590c3d2c00630f6c5a7a77edc1ef6436dfd85a6a7ee3"
	"shelf_static 1.1.3 c87c3875f91262785dade62d135760c2c69cb217ac759485334c5857ad89f6e3"
	"shelf_web_socket 2.0.0 073c147238594ecd0d193f3456a5fe91c4b0abbcc68bf5cd95b36c4e194ac611"
	"source_map_stack_trace 2.1.2 c0713a43e323c3302c2abe2a1cc89aa057a387101ebd280371d6a6c9fa68516b"
	"source_maps 0.10.12 708b3f6b97248e5781f493b765c3337db11c5d2c81c3094f10904bfa8004c703"
	"source_span 1.10.0 53e943d4206a5e30df338fd4c6e7a077e02254531b138a15aec3bd143c1a8b3c"
	"sprintf 7.0.0 1fc9ffe69d4df602376b52949af107d8f5703b77cda567c4d7d86a0693120f23"
	"sse 4.1.6 111a05843ea9035042975744fe61d5e8b95bc4d38656dbafc5532da77a0bb89a"
	"stack_trace 1.12.0 9f47fd3630d76be3ab26f0ee06d213679aa425996925ff3feffdec504931c377"
	"standard_message_codec 0.0.1+4 fc7dd712d191b7e33196a0ecf354c4573492bb95995e7166cb6f73b047f9cae0"
	"stream_channel 2.1.2 ba2aa5d8cc609d96bbb2899c28934f9e1af5cddbd60a827822ea467161eb54e7"
	"string_scanner 1.3.0 688af5ed3402a4bde5b3a6c15fd768dbf2621a614950b17f04626c431ab3c4c3"
	"sync_http 0.3.1 7f0cd72eca000d2e026bcd6f990b81d0ca06022ef4e32fb257b30d3d1014a961"
	"term_glyph 1.2.1 a29248a84fbb7c79282b40b8c72a1209db169a2e0542bce341da992fe1bc7e84"
	"test 1.25.8 713a8789d62f3233c46b4a90b174737b2c04cb6ae4500f2aa8b1be8f03f5e67f"
	"test_api 0.7.3 664d3a9a64782fcdeb83ce9c6b39e78fd2971d4e37827b9b06c3aa1edc5e760c"
	"test_core 0.6.5 12391302411737c176b0b5d6491f466b0dd56d4763e347b6714efbaa74d7953d"
	"typed_data 1.3.2 facc8d6582f16042dd49f2463ff1bd6e2c9ef9f3d5da3d9b087e244a7b564b3c"
	"unified_analytics 6.1.4 9f3c68cb30faa6d05b920498d2af79eace00fef0bae9beba9f3cda84fdbe46df"
	"usage 4.1.1 0bdbde65a6e710343d02a56552eeaefd20b735e04bfb6b3ee025b6b22e8d0e15"
	"uuid 4.5.1 a5be9ef6618a7ac1e964353ef476418026db906c4facdedaa299b7a2e71690ff"
	"vm_service 14.3.0 f6be3ed8bd01289b34d679c2b62226f63c0e69f9fd2e50a6b3c1c729a961041b"
	"vm_service_interface 1.1.0 f827453d9a3f8ceae04e389810da26f9b67636bdd13aa2dd9405b110c4daf59c"
	"vm_snapshot_analysis 0.7.6 5a79b9fbb6be2555090f55b03b23907e75d44c3fd7bdd88da09848aa5a1914c8"
	"watcher 1.1.0 3d2ad6751b3c16cf07c7fca317a1413b3f26530319181b37e3b9039b84fc01d8"
	"web 1.1.0 cd3543bd5798f6ad290ea73d210f423502e71900302dde696f8bff84bf89a1cb"
	"web_socket 0.1.6 3c12d96c0c9a4eec095246debcea7b86c0324f22df69893d538fcc6f1b8cce83"
	"web_socket_channel 3.0.1 9f187088ed104edd8662ca07af4b124465893caf063ba29758f97af57e61da8f"
	"webdriver 3.0.4 3d773670966f02a646319410766d3b5e1037efb7f07cc68f844d5e06cd4d61c8"
	"webkit_inspection_protocol 1.2.1 87d3f2333bb240704cd3f1c6b5b7acd8a10e7f0bc28c28dcf14e782014f4a572"
	"xml 6.5.0 b015a8ad1c488f66851d762d3090a21c600e479dc75e68328c52774040cf9226"
	"yaml 3.1.2 75769501ea3489fca56601ff33454fe45507ea3bfb014161abc3b43ae25989d5"
	"yaml_edit 2.2.1 e9c1a3543d2da0db3e90270dbb1e4eebc985ee5e3ffe468d83224472b2194a5f"
)

SRC_URI="
	https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${PV}-stable.tar.xz
	$(dart-pub_src_uri)
"
S="${WORKDIR}/flutter"

LICENSE="BSD"
# bundled flutter_tools dependencies
LICENSE+=" Apache-2.0 MIT"
SLOT="${PV}"
KEYWORDS="-* ~amd64"
RESTRICT="mirror strip"

QA_PREBUILT="
	opt/${PN}-${SLOT}/bin/cache/artifacts/engine/*
	opt/${PN}-${SLOT}/bin/cache/dart-sdk/bin/*
"

RDEPEND="
	dev-vcs/git
	>=sys-libs/glibc-2.18
"

src_unpack() {
	unpack "flutter_linux_${PV}-stable.tar.xz"
}

src_prepare() {
	default
	rm bin/*.bat || die
}

src_install() {
	dodir /opt
	cp -a "${S}" "${ED}"/opt/${PN}-${SLOT} || die

	dart-pub_populate "${ED}"/opt/${PN}-${SLOT}/.pub-cache
}
