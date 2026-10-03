using System.Security.Cryptography;
using System.Text;

namespace ChildTreatment.Api.Data;

/// <summary>
/// Encrypts sensitive free text before it is stored, on top of database encryption at rest.
/// AES-256-GCM; the stored value is "enc1:" + base64(nonce | tag | ciphertext).
/// </summary>
public sealed class FieldProtector
{
    private const string Prefix = "enc1:";
    private const int NonceSize = 12;
    private const int TagSize = 16;

    private readonly byte[] _key;

    public FieldProtector(byte[] key)
    {
        if (key.Length != 32)
            throw new ArgumentException("The field encryption key must be 32 bytes.", nameof(key));
        _key = key;
    }

    public static FieldProtector FromBase64(string? base64Key)
    {
        if (string.IsNullOrWhiteSpace(base64Key))
            throw new InvalidOperationException(
                "Encryption:Key is not configured. Set a base64-encoded 32-byte key.");
        return new FieldProtector(Convert.FromBase64String(base64Key));
    }

    public string Protect(string plaintext)
    {
        var plain = Encoding.UTF8.GetBytes(plaintext);
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var cipher = new byte[plain.Length];
        var tag = new byte[TagSize];

        using var aes = new AesGcm(_key, TagSize);
        aes.Encrypt(nonce, plain, cipher, tag);

        var packed = new byte[NonceSize + TagSize + cipher.Length];
        nonce.CopyTo(packed, 0);
        tag.CopyTo(packed, NonceSize);
        cipher.CopyTo(packed, NonceSize + TagSize);
        return Prefix + Convert.ToBase64String(packed);
    }

    public string Unprotect(string stored)
    {
        if (!stored.StartsWith(Prefix, StringComparison.Ordinal))
            throw new CryptographicException("Stored value is not in the expected encrypted format.");

        var packed = Convert.FromBase64String(stored[Prefix.Length..]);
        var nonce = packed.AsSpan(0, NonceSize);
        var tag = packed.AsSpan(NonceSize, TagSize);
        var cipher = packed.AsSpan(NonceSize + TagSize);
        var plain = new byte[cipher.Length];

        using var aes = new AesGcm(_key, TagSize);
        aes.Decrypt(nonce, cipher, tag, plain);
        return Encoding.UTF8.GetString(plain);
    }
}
