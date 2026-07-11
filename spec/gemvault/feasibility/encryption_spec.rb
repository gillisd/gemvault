require "openssl"

RSpec.describe "AES-256-GCM feasibility for encrypted gems" do
  let(:data) { File.binread(build_gem("secret", "1.0.0")) }
  let(:key) { OpenSSL::Random.random_bytes(32) }

  def encrypt(plaintext)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = key
    iv = cipher.random_iv
    [cipher.update(plaintext) + cipher.final, iv, cipher.auth_tag]
  end

  def decrypt(ciphertext, iv, tag)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = tag
    cipher.update(ciphertext) + cipher.final
  end

  it "round-trips .gem bytes through encrypt then decrypt" do
    ciphertext, iv, tag = encrypt(data)
    expect(decrypt(ciphertext, iv, tag)).to eq(data)
  end

  it "fails decryption when the auth tag is wrong" do
    ciphertext, iv, = encrypt(data)
    bad_tag = OpenSSL::Random.random_bytes(16)
    expect { decrypt(ciphertext, iv, bad_tag) }.to raise_error(OpenSSL::Cipher::CipherError)
  end
end
