// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_TESTHASH_DATA_HPP
#define MUMBLE_TESTHASH_DATA_HPP

#include <array>
#include <string_view>

struct Data {
	using List = std::array< std::string_view, 28 >;

	static constexpr List input = { "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
									"Nulla imperdiet est nec elit ornare dictum.",
									"Integer elementum risus ac ipsum sodales sagittis.",
									"Suspendisse id est id sapien elementum consequat ac sed magna.",
									"Praesent varius diam nec lorem semper elementum.",
									"Suspendisse elementum dolor et placerat tincidunt.",
									"Duis accumsan metus sed augue rutrum feugiat.",
									"Nam eu velit at massa fermentum rhoncus sed a diam.",
									"Nullam consectetur elit sit amet ante rutrum, eget consequat sem porttitor.",
									"Duis et ipsum mattis, tincidunt lacus sed, luctus risus.",
									"In convallis dui nec nisi pellentesque, ac maximus massa posuere.",
									"Curabitur quis mi tincidunt, maximus orci non, semper arcu.",
									"Pellentesque ac ex placerat massa tincidunt efficitur.",
									"Suspendisse quis neque ac neque suscipit fermentum et in ligula.",
									"Morbi in lacus et augue dapibus porttitor.",
									"Vestibulum tincidunt erat quis feugiat imperdiet.",
									"Donec auctor felis non urna congue, at pretium leo aliquam.",
									"In sollicitudin neque id eros tristique posuere.",
									"Mauris mattis erat at velit tempus bibendum.",
									"Duis tempus lectus eu turpis pulvinar, luctus maximus libero hendrerit.",
									"Nam sodales nibh sed tellus eleifend consectetur.",
									"Ut elementum lorem eu pulvinar fringilla.",
									"Phasellus non diam a odio accumsan suscipit eu vulputate lacus.",
									"In posuere est a nisi scelerisque, sed bibendum nibh gravida.",
									"Integer imperdiet nunc vitae orci porta, ac facilisis justo porttitor.",
									"Aenean egestas arcu ac sapien efficitur porttitor.",
									"Quisque quis erat sit amet nunc tincidunt vestibulum.",
									"Mauris ac dui ac elit ullamcorper consectetur." };

	static constexpr List sha2 = { "19d8350a48bb40d04b4045955a9d95599aa5bd5b8c74c36c098b58c3cd8af142b8d9cf0417ef6dc88c4"
								   "ed91c69ea8e2adce7afec1afb6a21d8cae681b0902997",
								   "9d99575c072d78a2c645658a651a3c7b212639e5de0ed10f6187915e4f87cb7b01fe678f752299d185a"
								   "2fa74d3353578557401ee318e7ae8f3eda144763c3334",
								   "55eaafe0e3031b6e4fefd1f315a1555896a40a16e3c66b5a04b27ce842af7c23e8f78548a7a3783a289"
								   "a2217c74f226285c444ea7c35311ee7af9d1b1c04ce02",
								   "3e2701773a1bba34ba7a09c47c5982932bb80c13a65991ce88189be0e234ac0c69d9fcff05d4a952ad6"
								   "0a7df19fcf19986869a221624b7a2685ea642cbaa407d",
								   "b64da7940d2cc526c4f2409f4f51f039588f06f3983ab444d45648c5cdca424c840c49e0d122cddc506"
								   "d328ec5671aa5c5c5fb34cedc3f3877aa9f629aee156f",
								   "3a797a4435af77b4c0e6976f77fca1af3c5e13d996f2c12d3e1d06ca5857338d999c8123eb71439a8c8"
								   "a9c2c1c553412bfc9eed239251bdfe7ea8d5f6d8677f7",
								   "408787283b33b4d037fcb85fb57531204f43ee19221a98fc8cf521387668d1f215c4e31b1235221adcd"
								   "a270d058715cb5cb3d3c3d05cdef1c5d7886d277fa219",
								   "a9111b465fa714690e8942125fa2fcc33740ce64ff9102a16dbefe03822fa2e88369b6592ab5bf5d408"
								   "471d4a824da234f5f613314fb4cbdaf196367d32e6f44",
								   "7022f99a08901d1a6a55f83105c9d1dca88580ca44c3451aed6e728b41f10154dfa3453a872d0f6c207"
								   "1606d471d86c73971de1dfbd29fa3b059ff0d83d43246",
								   "80c564f6e020ae585d4211314086c8fc017e25cdc1b943e323fd59f9d0d44293a6addeac19584e562d7"
								   "c83ab77a20cae2ac98dce281b5d5ee7b764f46b6c1e33",
								   "c7ce225a7da021de8fc30b6fe5b4824fece92fa9308fc91de65d7fc748ed01d8d2831c1df70b0ddd804"
								   "501aad9316bdafb45e943413f748580689b3c0a99b91a",
								   "d681f2051c59cfdc53f4568f9550814341af656af00c7463fc54d3d18607501104c02c69a3e90c38163"
								   "528a85b057a7ae65f2fb1d4366a4a605917f80dbf20d0",
								   "47e880f3b474fa1e427c27e9fbd157e4094c527ff26d64b41a2a96918f4f93746d5bf1396eeb11284c1"
								   "7cf5e1724a6373b5fd68def3042f4fd4d6ddde93f45ea",
								   "b7927008fec1b9ea7b31dbe2e604d0c7d9e3ad723f4f59d0d30185f54869f5d843c5ea482a9e5347169"
								   "678235ac00c0ce99d892b91b049f53cdb68ee25bae8f6",
								   "e6fa4ad4de92ff99102c847587a7fb111f462b882ab252db65627a4ec654426028f144f4728f33a5062"
								   "01806c9545051edd947941a57049ccf5f52f6322a0cc2",
								   "0d8b8be5226193eb6e183aec9bba261a111a17f9200404eca04d9e390ff36f20094e18855eab82f58a6"
								   "5c0e6059e8dbadeba41b75801e3766e40a8a5fd68524c",
								   "0a7eb4c3918cc6590dc24b52c25504aab7c03ec0c285c089a40d29d945392e995cc2fe636f42f814023"
								   "ed093f9e68a1fbd3a4ed3410382ff94a0a86c666f4ddf",
								   "0daf308573f0bbe923204b57710e1af6654fbe6905fa3891dbcf342caaf0ec4aa1784cc336c9baefb14"
								   "3242c55ca2718c6d9cbc0fe7e60a3e3f963162e15cd59",
								   "62e0463de7270b358d32e518480a75cf7943eb70d282c0d76ccdce659ba8d5aebfa66120693711bd922"
								   "d1be8b2a908ff6f8df15542511c3d5c8d58f2d0c73ca9",
								   "c3411d616427a859d04e6a565715b607da12474d2a0d176f7b8cf8efd1afc88c0a419e6afe4d046b688"
								   "efc1a3e06f95a8d807161eeb2cee6b3397a9f48fe744e",
								   "1d5a6ef3651c515814cc18cdf5a8021d42fa0791a557d55749356627089857c51f615b6a6115c43d105"
								   "16a23a9bd5f0c0667f997a36a0889bc0b07131f7b64e9",
								   "99adcfb44f8bf21484e1ace98bbac441f40094ef1b5357e3137eebe9db699e57533d8cce1b1df6fb10c"
								   "ce530749993b94483e2b045d9ad21cf3f751ec6e4a2d1",
								   "e140f40f7681ad28c058bc9f29913ce09d0962aa1a752411418db52d4886d79d4392bb0735098118f83"
								   "074bd192dd1ff03cda147a989684f7c7af8370ced71cb",
								   "a8b1f87c6baac2ef28c85f399c1f262b597c07ec0401378549e6d716460f70153990759ce512a5df0d5"
								   "2d30895d60bdca6f60da80e2823c5044c8f5e65e38a91",
								   "f66504389832b2b77a35334e677b9e461b8d9880b74653a6e1f95425ca5880ddc8267a73b13e6d04454"
								   "d2167068100a924c9f8d7b65c57e112d15185ceb44eb8",
								   "87a4c680360a090293f90d13d4c0a92b4bffc88ebd2593a65c58c60284d5b9a391fad82e9ad9f6afbf7"
								   "005a3b3bf50ab29e5bdefe509277f6e2ffbafdd1abcb8",
								   "17a9eb6cd99f573cdc699d10c39199a4929a8d43badfd0d596cf33b3ba45514c7813f6bcde48fcf6d5e"
								   "9a5e0cda8087542a30cbf7b10311903d39501030cd9fa",
								   "0cecc77780e6ad784fa0590dd2fb6ec0fe6b9f0b6b6d3a7a3fbf2e1b365488ae23dc442a74510ad2344"
								   "d5ca187a142d37466ba14b91803a68b7735626af42a24" };

	static constexpr List sha3 = { "efb580d4e7145bd4ddd10153624b747d21d09b79c0a2c708de09c19dcd6901a0c34d78ad0e7b7c64f46"
								   "b7f3ab85aeca7d0f718e9cf38089ad1c9cc05c45ae7ee",
								   "23d8557a0b00761561c9c73d02efd4dcd385760ba55dc3a8f327b51f658d489b3689e14f43e3525f175"
								   "bf7c4ca385fe943f2bbce5cfe228082110db8cab68df7",
								   "d5c387c8ac56045ff8b39154625fd8a237e11bfb4f15b0809c916537f1d3764cb2ac09ce83c25c8aa0c"
								   "515bcb250de3cf3d48cd84994518730d0bd780cda054c",
								   "a149379dc2017a96dca8277b6f4c9b646397fec313db731c70b2a3dfc02e0203b17802760de85d983c6"
								   "d8b2be29865e1814a3cbc62e8e7f2ff84f97e4d1b4cb3",
								   "a617eff3f975e727761155b00b595e7d77f3ef3c0fb85615bb48dd099a5d14c44288526cc29b2c60646"
								   "1f43a9c0bdd08c058228fc9725ef303086d62ceabdea6",
								   "ee0f565a9a98221c6e192a435fe7adf88da948fb0fb901c94cf1e43833028bf27f2e23358ce0ef8bafa"
								   "b7380261f361ea36749a58e65b6515a9a7ca184ae91d4",
								   "0ee273a19beab4a9b5a27283adf3fbbe86ab02f1a2f1943a74b94ad9a1c6fe8b08fb7c31e34b49f3eb7"
								   "57c69318c1fb5adb82a4105540b978929fe4b92e5506f",
								   "e48141f181030ea8fce5e190e80720e225b68eac4c7d08a587dbdef39c22a04fdcc411d643e4566b627"
								   "a630df8f07dc6d7c558ea53e5c14450570b4e6c0c78c5",
								   "95d6b2ce50c4cc4eefc23ae1e90ff1e5dfe558a964ac3fa38aa72267b1e699573833cd261b1125c7420"
								   "717988c7a67a046346250f5374e62b0579ce98e97f7a2",
								   "665ac75373ce267bcf1e208c6acb53a666f7fe2938a80d122922e8f62fc2ba9cbb902888f7175d6c926"
								   "bd5351bc800b7e1477da73b2048ce8601b06c33f4149d",
								   "1ad6fc0db5ab1b9d12a47563d0fbc03680576d7e06efd8179da0033b487344df36ea9a40e33fae6cb3e"
								   "7d0fb11b27bbbd261e8cc9f71ae1cdaeff4a54c4cfd31",
								   "8872075ecfa7ad588360e7af34ff763a7e4940c415136d316e174bd42b40c9c6f49730645063bccad0e"
								   "ccd1d59f68636b629228490bcdf80908b939c6342dbea",
								   "cb960853434abc5a9801ee31da4629e4809829390d40ea66b97decad472e919e309d29046bf1a2065f7"
								   "c3ac544c417f10d230bcf8afc5ab9c1eedfccc39f3522",
								   "0fc735573e40765ec0aa4c6ded2faeaa30a3519acf15949c5e1cd8e84bcdc11ba2059d3f53141ec4995"
								   "b27f5fb1de38041d82b4ba0bff31921bfd66f71a7f91e",
								   "90447014677aed202276331f99f6b5c9bbd90539686ce7068f6ee09ece97787d6f816fa04e0abd47ebf"
								   "3db301dc35a07dcb3b5185ecc236b21cbdc95dd00925f",
								   "a74b103dc5d5b5e2d2b284cfba30c90083e194bc2d93d92851f90b6de413989ac28d60e1210e0b8fd97"
								   "a7da247ac80c7d8b1119b62d11442d1f1f3fb14369407",
								   "dfb0d649655d5706e6021dafe74225d0b8a55457971f3477b4d6c1fcb5c7954cec001c7352575558aa9"
								   "c015538d08ef4b882d85db62ef904e562c6b0fa8fa4fd",
								   "da348f2508a2cbb548e2f02c778c72cb1b2b180cab50746ce3c5ebd2a710e8c626ad995b051f4e84507"
								   "c53381808396dd055bcfad1bd1b095fc181ee76237bd4",
								   "9faf8175a2c5817e880cb175bcfaec22835d04b5b38b85400fda1df0f61b36fb7226a39af3cfb0ae205"
								   "ef16ea07f81d3ed4e50aa0755679426ad04e1f061ccd0",
								   "950e46c2ccb752118a144f8d8b73b2b4459ad64ffcc206f918ff60fb585d195f94cec808662c99f54e2"
								   "2d0d3805fbac0cbcc055afc86497ab4b404df412db790",
								   "a03432ddd7de8aaa120164d37b38e548bdf16cd5f830f9e08d4da37f81019b62a3bf6c1454c1a518ebd"
								   "7fe1e2cfa0b72b6b091c0d7255805db6ec3c9347bae27",
								   "24111a987ea25cd8d207aa747d98deaf535dfc5bc6f7d6bf8cbc3ecec07a28b531ce2f9ee58593425ce"
								   "44f6e3c8be8cd993a17fa92e4d4624d139205787448f4",
								   "b51cefbf73aac85856eac653006f69c6791ca4bea00118090fd7bdb02e18a7a47863b8b64b067333098"
								   "67e005fc39cb8a6ed99660d9e4db021d41e273774fb8e",
								   "6f77d223257661d9676fd4dcc8e5f3dc27d0820be501151032a6fa8982676446c72d129ed5aae88ae8d"
								   "df474ca0c19ae676b66cbbaffef1066f18073e5d9eafb",
								   "e9e4e4da801ae978d39e5567f19003d9223204f0187acb8f1765dbae9c65ceb11f85f442862e3b07773"
								   "069c5249e2f0a0dfc6c849053e61f6f6acbb1f5ec4e6b",
								   "65aad56467dc4763459ef59dc3d43695ddafd42a5397ea73988fdc9787571589b7d49f8e4b746f1dcb5"
								   "5319105d7862b4811a7d4268834cbda63d8a8c96cc52e",
								   "ef31dc80cb514af1ee55e492e8e74b3f87c463a7a7516b49bf0deaef7a793ea311736cd7b0d7d5a7789"
								   "3f1204f75d2a9e0c164f474716772c3ee01c19d241ea1",
								   "81e9521dfc7e127d09f7c5a995e62829dccd59e883a28de60aa8dcba87587a3a63c05b6ed6e7c1c919f"
								   "a8910ff1efe59576b6dd07badcbb2bdcf54647426540a" };

	static constexpr List blake2b = { "d6a1c4f1083b7535f7314305ac77fc6525b13333554e6a43bc75ef21f7fffc263b23fe1b713aac41"
									  "151c50a4793c02cd7fcf66adbbacef4c547e8271c3d35111",
									  "ac31660807101f9489bdaa0279739517bc459cfaba5407fb045cd341740f538fdde3e65324408849"
									  "e9284447fb52b96681a3dd4054575f5264d823cae4dcd20d",
									  "382f8e4a5644da4ce6786162b8c04debba40939fb8daccd160fdba6edfb53c12e506a7b610152110"
									  "725936a233b4439c52b44121ca7d33a56ec9559d3c73f542",
									  "659063eabaf58af5cca78f071f011ce74bc787751d8c3a68e0f9ce55701691c26a2b8b18f1eb4de2"
									  "7b2afc8ffd95aed549bdf4694a337653fe428c8d6012360a",
									  "adfdd1b7a65de62278ac785258f1e9bcde3cd6287192e709d5f03d5e5ad402246b6e8bae07d08165"
									  "a269e990279fd05e7b1983f7f3e37aadcba5387ba973aee9",
									  "694deb150ab0d0f9c5325457ad0d719d4406ed9fd907e9458552210779dfde0b0df4adceb9fbd19c"
									  "9fd2f4d07cb034484c7264595db10ce8b833c9ec48f47faa",
									  "951cba5ebb1f240854da1be35c8a1231a411ee0f1c2887f803481649b80fc49ac9e07454e3c6058e"
									  "18cbd53f22e571021fe84a360acc8c45cb185c0bd45db93d",
									  "411af999509db841829db55f47de014dd5044b2ccd1d2e2075ffc109286b4f10796f85f8906424aa"
									  "28b54532367e240849c659fa08713f9b9aab8314bd638138",
									  "db2fb74b6d63081eb37c301f2fe44c216bc1d3e43d140e6f3fbe4ca54817dfdd88150cfaa58a0c58"
									  "0e13bcb82924a83aff2e548ca335fe9943f20bd95b84196b",
									  "57560110babfa14db2ee87405dda8474024483532bba1e477fec240bf23e545d439e63586f86c353"
									  "967415f346c7798a6210e41eb88a483be267119686949619",
									  "1457474d0d43b624518d6fb711cddb16cba05fc83bed4d5578605fcced013b55c42ebaa8b2a50334"
									  "298d6246039da46f1526f3383574b9331001767feedd044f",
									  "f08dfdfac506e049e664448e0c5b4d33e2de231149100eac09ff74848b4f84d8df2c381d1abc82e0"
									  "f3d65d3e7e2706d8ae6358948da8429c73db957ad5b97e51",
									  "fc66255f2e72016a4d63890d5e431b301a037659b488784ed719d60a413c4cef766f725b9795f5bc"
									  "1938aa42d7a91ad8e0486798fcec397e7cad17cdb73955c1",
									  "c7bbc9b6f6576168c24535ac0505789dff54e8730a14c60d05c8e55c11977bb1cc184916a3882d69"
									  "076dad5303b80d74a05b76a9c84c2542f7d7a66c20ce0863",
									  "dc70957d01efcddf911e23cde30752e800a99bc8a9b666f86f6966d1f5dc5c16bb6869b1f95e9cb4"
									  "1d6fdc49aeca9f0f7bbc4f1b4e7c6fe08bfd41423b62804c",
									  "b72ff549afd251ced20e8e84bf4a35b085a9a57621b0c87ac0eac7686da6d1337e4d0baaad4b6614"
									  "9b287244c1857cfc29f1dbe566334f09d6b2ba561e3bd4d9",
									  "275ca19b23b71966c59f6c6d8148a0cb11d9cd77befa50bf472337fe00847bbc24c87bbd2c98786d"
									  "338becc524fde1c328474a205a5d457b99df4a00e7b08400",
									  "15ed42894abf35f74c7b13c688ef49a5673ab70b72933801293e92d1ea4a83b80a78e7fe53edc336"
									  "cd20afd0ba4cfd06d30c3898fbf397220345f39fc40c2df0",
									  "760815f17f32aba7ef13c761380d5e33f9944c7d83338d979f82122e35df3b897299614dfbe1bbce"
									  "c12f8d3313fa1b795e3ce7926f2bbbc3272e0f6fff421951",
									  "38e649a7c441fce8a3c590705127d9abbf301dddb4b2acd2c2ed8daec17abcba2e3ca57b3d324721"
									  "1d6d196b787e0cccca2a759048efa0efbe13f4972b012eb4",
									  "6c1c3c2bd69929ee42d2bfc4892aa2d4135bbe49c6cb7cbf6209d398b4f9c753d01eda07433f03bd"
									  "3dbd581d06b1b3b80128f213f78d51c87f1355b212cf922d",
									  "f99bf2574aa1a0b86c943f7c34c874c1e4bd7ef6a14202e8c1b83f0f285dc4c48a110301d10a3be2"
									  "550dc4664d01e27e4f49cb18d1811bb5487eca39c12f75db",
									  "c098a76d0eedbc5da990ec6bf58a3d4401a660eb46d8cb1af3863c5eea71a130317205fc74a50135"
									  "547f74e0c07330e3078a0e53ecfeb3a53ef1f1970e5ced3d",
									  "816c2497a4cc2c8cd40e8c41e51ce33148e80b0dbe8c86b7e4f8ec9737d1f0ead806ff583dc0ee12"
									  "501897755f7b95a5b3c5db4dff49ffcb089b17480125ea8a",
									  "cbf5d620558999b18293a91b3337c0a3a017a9c4f01cb2fe897be18f46a56bd543ed50f90fa40513"
									  "6ef0d91b3beb0cc88e3223a1957074e458b594c034c102a3",
									  "ed560d6b13f5e4a1f11b9a0b3333abc3e761bf9df20c827bb9739632c7e09805eedbd29afadb1dc8"
									  "dc20a745cc3b275d539820216d0186e7cf826054eefe421d",
									  "faa1f5563b2e30366bf2a495606242bac3644bde189e46a55db7f4cac88950d552989e2f69672169"
									  "46d448de8818770ff75d83edf53f1a4219a17450ced0adf2",
									  "176814aa8930a9abbbb6071806f6dade00141c8661d758130dce5861f5d07ce008db2c4822ff868d"
									  "72532239c51d46eb5116cc41638b61a1fc67509e8857865c" };
};

#endif
