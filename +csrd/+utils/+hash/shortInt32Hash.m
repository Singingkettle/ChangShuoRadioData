function value = shortInt32Hash(text)
%SHORTINT32HASH Deterministic non-negative int32 hash of a UTF-8 string.
%
%   value = csrd.utils.hash.shortInt32Hash(text)
%
%   Inputs:
%     text : char or string scalar; will be converted to a char row vector.
%
%   Outputs:
%     value : double scalar in [0, 2^31 - 1].
%
%   Implementation:
%     - Computes MD5(utf-8(text)) via java.security.MessageDigest.
%     - Takes the first 4 bytes, interprets them as a big-endian uint32,
%       then masks the sign bit so the result fits in int32 non-negative
%       range. The output is suitable for use as a deterministic seed.
%
%   This function is intentionally Phase 1 only and is **not** the same
%   as the Phase 2 BlueprintHash (SHA-256). MD5 is used purely for hash
%   dispersion of short identifier strings, with no security claim.
%
%   Phase 1 / H13 ChannelFactory.deriveChannelSeed uses this helper to
%   derive a (TxId, RxId, BurstId)-aware channel seed.

    if isstring(text)
        text = char(text);
    end
    if ~ischar(text)
        error('CSRD:Hash:BadInput', ...
            'shortInt32Hash expects a char or string scalar; got %s.', class(text));
    end
    if isempty(text)
        % Define an explicit constant for the empty input so the hash is
        % stable and not platform dependent on JVM behaviour for zero
        % length input.
        value = 0;
        return;
    end

    md = java.security.MessageDigest.getInstance('MD5');
    md.update(uint8(unicode2native(text, 'UTF-8')));
    digestBytes = typecast(md.digest(), 'uint8');

    if numel(digestBytes) < 4
        error('CSRD:Hash:DigestTooShort', ...
            'MD5 digest unexpectedly returned %d bytes.', numel(digestBytes));
    end

    % Big-endian uint32 from the first 4 digest bytes, then mask the sign
    % bit so the value fits in MATLAB's int32 non-negative range.
    raw = uint32(digestBytes(1)) * 2^24 + ...
          uint32(digestBytes(2)) * 2^16 + ...
          uint32(digestBytes(3)) * 2^8  + ...
          uint32(digestBytes(4));
    masked = bitand(raw, uint32(2^31 - 1));
    value = double(masked);
end
