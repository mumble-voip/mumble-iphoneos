#import "MLInternal.hpp"
#include <mumble/Cert.hpp>
#include <openssl/evp.h>
#include <openssl/pkcs12.h>
#include <openssl/provider.h>
#include <openssl/rand.h>
#include <openssl/x509v3.h>

NSString *MLCertificateItemCommonName = @"CN";
NSString *MLCertificateItemOrganization = @"O";

static NSData *MLDERCertificate(X509 *certificate) {
    if (!certificate) return nil;
    int size = i2d_X509(certificate, nullptr);
    if (size <= 0) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    auto bytes = static_cast<unsigned char *>(data.mutableBytes);
    return i2d_X509(certificate, &bytes) == size ? data : nil;
}
static NSData *MLDERKey(EVP_PKEY *key) {
    if (!key) return nil;
    int size = i2d_PrivateKey(key, nullptr);
    if (size <= 0) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    auto bytes = static_cast<unsigned char *>(data.mutableBytes);
    return i2d_PrivateKey(key, &bytes) == size ? data : nil;
}
static EVP_PKEY *MLReadKey(NSData *data) {
    auto bytes = static_cast<const unsigned char *>(data.bytes);
    return data.length ? d2i_AutoPrivateKey(nullptr, &bytes, (long)data.length) : nullptr;
}

@implementation MLCertificate {
    NSData *_certificate, *_privateKey;
}
+ (instancetype)certificateWithCertificate:(NSData *)certificate privateKey:(NSData *)key {
    mumble::Cert parsed(MLBytes(certificate));
    if (!parsed) return nil;
    MLCertificate *result = [self new];
    result->_certificate = [certificate copy];
    result->_privateKey = [key copy];
    return result;
}
+ (instancetype)selfSignedCertificateWithName:(NSString *)name email:(NSString *)email {
    EVP_PKEY_CTX *context = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nullptr);
    EVP_PKEY *key = nullptr;
    X509 *certificate = X509_new();
    BOOL ok = context && certificate && EVP_PKEY_keygen_init(context) > 0 &&
        EVP_PKEY_CTX_set_rsa_keygen_bits(context, 2048) > 0 && EVP_PKEY_keygen(context, &key) > 0;
    if (ok) {
        unsigned char serial[16];
        ok = RAND_bytes(serial, sizeof(serial)) > 0;
        serial[0] &= 0x7f;
        BIGNUM *number = ok ? BN_bin2bn(serial, sizeof(serial), nullptr) : nullptr;
        ok = number && BN_to_ASN1_INTEGER(number, X509_get_serialNumber(certificate));
        BN_free(number);
        ok = ok && X509_set_version(certificate, 2) && X509_set_pubkey(certificate, key) &&
            X509_gmtime_adj(X509_getm_notBefore(certificate), -60) &&
            X509_gmtime_adj(X509_getm_notAfter(certificate), 60L*60*24*365*20);
        X509_NAME *subject = X509_get_subject_name(certificate);
        NSData *commonName = [(name.length ? name : @"Mumble User") dataUsingEncoding:NSUTF8StringEncoding];
        ok = ok && X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_UTF8,
            static_cast<const unsigned char *>(commonName.bytes), (int)commonName.length, -1, 0);
        if (email.length) {
            // Construct ASN.1 directly; email text is never interpreted as extension syntax.
            GENERAL_NAMES *names = sk_GENERAL_NAME_new_null();
            GENERAL_NAME *general = GENERAL_NAME_new();
            ASN1_IA5STRING *address = ASN1_IA5STRING_new();
            NSData *bytes = [email dataUsingEncoding:NSASCIIStringEncoding];
            if (names && general && address && bytes &&
                ASN1_STRING_set(address, bytes.bytes, (int)bytes.length)) {
                GENERAL_NAME_set0_value(general, GEN_EMAIL, address);
                address = nullptr;
                sk_GENERAL_NAME_push(names, general);
                general = nullptr;
                ok = ok && X509_add1_ext_i2d(certificate, NID_subject_alt_name, names, 0, 0);
            } else { ok = NO; }
            ASN1_IA5STRING_free(address);
            GENERAL_NAME_free(general);
            GENERAL_NAMES_free(names);
        }
        ok = ok && X509_set_issuer_name(certificate, subject) && X509_sign(certificate, key, EVP_sha256()) > 0;
    }
    MLCertificate *result = ok ? [self certificateWithCertificate:MLDERCertificate(certificate) privateKey:MLDERKey(key)] : nil;
    X509_free(certificate); EVP_PKEY_free(key); EVP_PKEY_CTX_free(context);
    return result;
}
+ (NSArray *)certificatesWithPKCS12:(NSData *)data password:(NSString *)password {
    if (!data.length) return nil;
    // Required only to import existing identities encrypted with older PKCS#12 algorithms.
    static dispatch_once_t once;
    dispatch_once(&once, ^{ OSSL_PROVIDER_load(nullptr, "default"); OSSL_PROVIDER_load(nullptr, "legacy"); });
    auto bytes = static_cast<const unsigned char *>(data.bytes);
    PKCS12 *container = d2i_PKCS12(nullptr, &bytes, (long)data.length);
    EVP_PKEY *key = nullptr; X509 *leaf = nullptr; STACK_OF(X509) *chain = nullptr;
    if (!container || !PKCS12_parse(container, password.UTF8String ?: "", &key, &leaf, &chain)) {
        PKCS12_free(container); EVP_PKEY_free(key); X509_free(leaf); sk_X509_pop_free(chain, X509_free);
        return nil;
    }
    NSMutableArray *result = [NSMutableArray array];
    MLCertificate *first = [self certificateWithCertificate:MLDERCertificate(leaf) privateKey:MLDERKey(key)];
    if (first) [result addObject:first];
    for (int i=0; i<sk_X509_num(chain); ++i) {
        MLCertificate *item = [self certificateWithCertificate:MLDERCertificate(sk_X509_value(chain,i)) privateKey:nil];
        if (item) [result addObject:item];
    }
    PKCS12_free(container); EVP_PKEY_free(key); X509_free(leaf); sk_X509_pop_free(chain, X509_free);
    return result.count ? result : nil;
}
+ (instancetype)certificateWithPKCS12:(NSData *)data password:(NSString *)password {
    return [[self certificatesWithPKCS12:data password:password] firstObject];
}
+ (NSData *)exportCertificateChainAsPKCS12:(NSArray *)chain withPassword:(NSString *)password {
    MLCertificate *first = chain.firstObject;
    if (!first.hasCertificate) return nil;
    mumble::Cert certificate(MLBytes(first.certificate));
    EVP_PKEY *key = MLReadKey(first.privateKey);
    STACK_OF(X509) *extra = sk_X509_new_null();
    for (MLCertificate *item in [chain subarrayWithRange:NSMakeRange(1, chain.count-1)]) {
        mumble::Cert parsed(MLBytes(item.certificate));
        if (parsed) sk_X509_push(extra, X509_dup(static_cast<X509 *>(parsed.handle())));
    }
    // Security.framework's PKCS#12 reader requires the interoperable PKCS#12
    // PBE format. This container format does not change the certificate's
    // SHA-256 signature or the TLS cipher policy.
    const char *passphrase=password.UTF8String ?: "";
    PKCS12 *container = PKCS12_create(passphrase, "Mumble Identity", key,
        static_cast<X509 *>(certificate.handle()), extra,
        NID_pbe_WithSHA1And3_Key_TripleDES_CBC, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, 0, 0, 0);
    if (container && !PKCS12_set_mac(container, passphrase, -1, nullptr, 0, PKCS12_DEFAULT_ITER, EVP_sha1())) {
        PKCS12_free(container); container=nullptr;
    }
    int size = container ? i2d_PKCS12(container, nullptr) : 0;
    NSMutableData *data = size > 0 ? [NSMutableData dataWithLength:size] : nil;
    if (data) { auto bytes = static_cast<unsigned char *>(data.mutableBytes); i2d_PKCS12(container, &bytes); }
    PKCS12_free(container); EVP_PKEY_free(key); sk_X509_pop_free(extra, X509_free);
    return data;
}
- (NSData *)exportPKCS12WithPassword:(NSString *)password {
    return [MLCertificate exportCertificateChainAsPKCS12:@[self] withPassword:password];
}
- (BOOL)hasCertificate { return _certificate.length > 0; }
- (BOOL)hasPrivateKey { return _privateKey.length > 0; }
- (NSData *)certificate { return _certificate; }
- (NSData *)privateKey { return _privateKey; }
- (NSData *)digest { return [self digestOfKind:@"sha1"]; }
- (NSData *)digestOfKind:(NSString *)kind {
    const EVP_MD *algorithm = EVP_get_digestbyname(kind.UTF8String);
    if (!algorithm) return nil;
    unsigned char digest[EVP_MAX_MD_SIZE]; unsigned int size=0;
    return EVP_Digest(_certificate.bytes, _certificate.length, digest, &size, algorithm, nullptr) ?
        [NSData dataWithBytes:digest length:size] : nil;
}
- (NSString *)hexDigest { return [self hexDigestOfKind:@"sha1"]; }
- (NSString *)hexDigestOfKind:(NSString *)kind {
    NSData *digest = [self digestOfKind:kind];
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger i=0; i<digest.length; ++i) [text appendFormat:@"%02x", static_cast<const uint8_t *>(digest.bytes)[i]];
    return digest ? text : nil;
}
- (NSDate *)notBefore {
    mumble::Cert certificate(MLBytes(_certificate));
    return [NSDate dateWithTimeIntervalSince1970:std::chrono::duration<double>(certificate.since().time_since_epoch()).count()];
}
- (NSDate *)notAfter {
    mumble::Cert certificate(MLBytes(_certificate));
    return [NSDate dateWithTimeIntervalSince1970:std::chrono::duration<double>(certificate.until().time_since_epoch()).count()];
}
- (BOOL)isValidOnDate:(NSDate *)date { return [date compare:self.notBefore] != NSOrderedAscending && [date compare:self.notAfter] != NSOrderedDescending; }
- (BOOL)isSignedBy:(MLCertificate *)parent {
    mumble::Cert child(MLBytes(_certificate)), issuer(MLBytes(parent.certificate));
    auto key = issuer.publicKey();
    return child && issuer && key && X509_verify(static_cast<X509 *>(child.handle()), static_cast<EVP_PKEY *>(key.handle())) == 1;
}
- (NSString *)subjectItem:(NSString *)item {
    mumble::Cert certificate(MLBytes(_certificate)); auto attrs = certificate.subjectAttributes();
    auto found = attrs.find(MLUTF8(item)); return found != attrs.end() ? MLString(found->second) : nil;
}
- (NSString *)issuerItem:(NSString *)item {
    mumble::Cert certificate(MLBytes(_certificate)); auto attrs = certificate.issuerAttributes();
    auto found = attrs.find(MLUTF8(item)); return found != attrs.end() ? MLString(found->second) : nil;
}
- (NSString *)commonName { return [self subjectItem:@"CN"]; }
- (NSString *)subjectName { return self.commonName ?: self.emailAddress ?: @""; }
- (NSString *)issuerName { return [self issuerItem:@"CN"] ?: @""; }
- (NSString *)emailAddress {
    mumble::Cert certificate(MLBytes(_certificate));
    GENERAL_NAMES *names = static_cast<GENERAL_NAMES *>(X509_get_ext_d2i(static_cast<X509 *>(certificate.handle()), NID_subject_alt_name, nullptr, nullptr));
    NSString *result = nil;
    for (int i=0; i<sk_GENERAL_NAME_num(names); ++i) {
        GENERAL_NAME *name = sk_GENERAL_NAME_value(names,i);
        if (name->type == GEN_EMAIL) {
            result = [[NSString alloc] initWithBytes:ASN1_STRING_get0_data(name->d.ia5) length:ASN1_STRING_length(name->d.ia5) encoding:NSASCIIStringEncoding]; break;
        }
    }
    GENERAL_NAMES_free(names); return result;
}
@end
