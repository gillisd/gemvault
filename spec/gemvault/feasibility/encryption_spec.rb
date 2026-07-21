require "openssl"

RSpec.describe "AES-256-GCM feasibility for encrypted gems" do
  let(:gem_bytes) { File.binread(build_gem(name: "secret", version: "1.0.0")) }
  let(:key) { OpenSSL::Random.random_bytes(32) }

  def encrypt(plaintext)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = key
    iv = cipher.random_iv
    { ciphertext: cipher.update(plaintext) + cipher.final, iv: iv, tag: cipher.auth_tag }
  end

  def decrypt(ciphertext:, iv:, tag:)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = tag
    cipher.update(ciphertext) + cipher.final
  end

  it "round-trips .gem bytes through encrypt then decrypt" do
    expect(decrypt(**encrypt(gem_bytes))).to eq(gem_bytes)
  end

  it "fails decryption when the auth tag is wrong" do
    encrypted = encrypt(gem_bytes)
    expect { decrypt(**encrypted, tag: OpenSSL::Random.random_bytes(16)) }.to raise_error(OpenSSL::Cipher::CipherError)
  end
end
