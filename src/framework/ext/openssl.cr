require "openssl"

lib LibCrypto
  type BIGNUM = Void*
  type EVP_PKEY = Void*
  type RSA = Void*

  alias PasswordCallback = (Char*, Int, Int, Void*) -> Int

  fun bn_new = BN_new : BIGNUM
  fun bn_free = BN_free(bn : BIGNUM)
  fun bn_dec2bn = BN_dec2bn(a : BIGNUM*, str : Char*) : Int

  fun evp_pkey_new = EVP_PKEY_new : EVP_PKEY
  fun evp_pkey_free = EVP_PKEY_free(pkey : EVP_PKEY)
  {% if compare_versions(OPENSSL_VERSION, "3.0.0") >= 0 %}
    fun evp_pkey_size = EVP_PKEY_get_size(pkey : EVP_PKEY) : Int
  {% else %}
    fun evp_pkey_size = EVP_PKEY_size(pkey : EVP_PKEY) : Int
  {% end %}
  fun evp_pkey_get1_rsa = EVP_PKEY_get1_RSA(pkey : EVP_PKEY) : RSA
  fun evp_pkey_set1_rsa = EVP_PKEY_set1_RSA(pkey : EVP_PKEY, key : RSA) : Int

  fun rsa_new = RSA_new : RSA
  fun rsa_free = RSA_free(rsa : RSA)
  fun rsa_public_key_dup = RSAPublicKey_dup(rsa : RSA) : RSA
  fun rsa_generate_key_ex = RSA_generate_key_ex(rsa : RSA, bits : Int, e : BIGNUM, cb : Void*) : Int

  fun pem_read_bio_private_key = PEM_read_bio_PrivateKey(bp : Bio*, x : EVP_PKEY*, cb : PasswordCallback, u : Void*) : EVP_PKEY
  fun pem_read_bio_pubkey = PEM_read_bio_PUBKEY(bp : Bio*, x : EVP_PKEY*, cb : PasswordCallback, u : Void*) : EVP_PKEY
  fun pem_write_bio_pkcs8_private_key = PEM_write_bio_PKCS8PrivateKey(bp : Bio*, x : EVP_PKEY, enc : EVP_CIPHER, kstr : Char*, klen : Int, cb : PasswordCallback, u : Void*) : Int
  fun pem_write_bio_pubkey = PEM_write_bio_PUBKEY(bp : Bio*, x : EVP_PKEY) : Int

  fun evp_sign_final = EVP_SignFinal(ctx : EVP_MD_CTX, md : UInt8*, s : UInt*, pkey : EVP_PKEY) : Int
  fun evp_verify_final = EVP_VerifyFinal(ctx : EVP_MD_CTX, sigbuf : UInt8*, siglen : UInt, pkey : EVP_PKEY) : Int

  fun bio_new_mem_buf = BIO_new_mem_buf(buf : UInt8*, len : Int) : Bio*
  fun bio_free_all = BIO_free_all(bio : Bio*)
end

# OpenSSL RSA extension.
#
# Adds the RSA primitives Ktistec needs on top of Crystal's
# standard-library OpenSSL support.
#
module OpenSSL
  # RSA key.
  #
  # A private or public key backed by an `EVP_PKEY` handle.
  #
  class RSA
    # Raised on any failure in this module.
    #
    class Error < OpenSSL::Error
    end

    @pkey : LibCrypto::EVP_PKEY

    # Wraps a native key handle.
    #
    protected def initialize(@pkey : LibCrypto::EVP_PKEY, @is_private : Bool)
    end

    # Generates an RSA private key.
    #
    def self.generate(bit_size : Int, exponent : Int) : RSA
      bn = LibCrypto.bn_new
      raise Error.new("BN_new failed") if bn.null?
      begin
        if LibCrypto.bn_dec2bn(pointerof(bn), exponent.to_s) == 0
          raise Error.new("BN_dec2bn failed")
        end
        rsa = LibCrypto.rsa_new
        raise Error.new("RSA_new failed") if rsa.null?
        begin
          if LibCrypto.rsa_generate_key_ex(rsa, bit_size.to_i, bn, Pointer(Void).null) != 1
            raise Error.new("RSA_generate_key_ex failed")
          end
          pkey = new_pkey_from_rsa(rsa)
        ensure
          LibCrypto.rsa_free(rsa)
        end
        new(pkey, true)
      ensure
        LibCrypto.bn_free(bn)
      end
    end

    # Parses a key from a PEM string.
    #
    def self.new(pem : String, is_private : Bool) : RSA
      bio = LibCrypto.bio_new_mem_buf(pem.to_unsafe, pem.bytesize)
      raise Error.new("BIO_new_mem_buf failed") if bio.null?
      begin
        pkey =
          if is_private
            LibCrypto.pem_read_bio_private_key(bio, nil, nil, nil)
          else
            LibCrypto.pem_read_bio_pubkey(bio, nil, nil, nil)
          end
        raise Error.new("invalid PEM key") if pkey.null?
        new(pkey, is_private)
      ensure
        LibCrypto.bio_free_all(bio)
      end
    end

    # Builds a public key from the public portion of this key.
    #
    def public_key : RSA
      rsa = LibCrypto.evp_pkey_get1_rsa(@pkey)
      raise Error.new("EVP_PKEY_get1_RSA failed") if rsa.null?
      begin
        pub = LibCrypto.rsa_public_key_dup(rsa)
        raise Error.new("RSAPublicKey_dup failed") if pub.null?
        begin
          RSA.new(self.class.new_pkey_from_rsa(pub), false)
        ensure
          LibCrypto.rsa_free(pub)
        end
      ensure
        LibCrypto.rsa_free(rsa)
      end
    end

    # Reports whether this is a private key.
    #
    def private? : Bool
      @is_private
    end

    # Serializes to a PEM string.
    #
    def to_pem : String
      io = IO::Memory.new
      bio = OpenSSL::BIO.new(io)
      begin
        result =
          if private?
            LibCrypto.pem_write_bio_pkcs8_private_key(bio, @pkey, nil, nil, 0, nil, nil)
          else
            LibCrypto.pem_write_bio_pubkey(bio, @pkey)
          end
        raise Error.new("PEM serialization failed") if result != 1
      ensure
        LibCrypto.bio_free_all(bio.to_unsafe)
      end
      io.to_s
    end

    # Signs data using digest and returns signature.
    #
    def sign(digest : OpenSSL::Digest, data : String) : Bytes
      raise Error.new("can't sign with a public key") unless private?
      digest.update(data)
      buffer = Bytes.new(LibCrypto.evp_pkey_size(@pkey))
      if LibCrypto.evp_sign_final(digest, buffer, out len, @pkey) != 1
        raise Error.new("EVP_SignFinal failed")
      end
      buffer[0, len.to_i]
    end

    # Verifies signature against data and a digest.
    #
    def verify(digest : OpenSSL::Digest, signature : Bytes, data : String) : Bool
      digest.update(data)
      case LibCrypto.evp_verify_final(digest, signature, signature.size.to_u, @pkey)
      when 1
        true
      when 0
        false
      else
        raise Error.new("EVP_VerifyFinal failed")
      end
    end

    def finalize
      LibCrypto.evp_pkey_free(@pkey)
    end

    def to_unsafe
      @pkey
    end

    # Wraps an `RSA` object in a fresh `EVP_PKEY` handle.
    #
    protected def self.new_pkey_from_rsa(rsa : LibCrypto::RSA) : LibCrypto::EVP_PKEY
      pkey = LibCrypto.evp_pkey_new
      raise Error.new("EVP_PKEY_new failed") if pkey.null?
      if LibCrypto.evp_pkey_set1_rsa(pkey, rsa) != 1
        LibCrypto.evp_pkey_free(pkey)
        raise Error.new("EVP_PKEY_set1_RSA failed")
      end
      pkey
    end
  end
end
