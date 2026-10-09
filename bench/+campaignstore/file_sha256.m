function digest = file_sha256(path)
%FILE_SHA256 Return an uppercase streaming SHA-256 digest for a file.

if ~isfile(path)
    error('campaignstore:MissingFile','File does not exist: %s',path);
end
md = java.security.MessageDigest.getInstance('SHA-256');
stream = java.security.DigestInputStream( ...
    java.io.FileInputStream(java.io.File(path)),md);
cleanup = onCleanup(@() stream.close());
byteBuffer = javaMethod('allocate','java.nio.ByteBuffer',1024*1024);
buffer = byteBuffer.array();
while stream.read(buffer) >= 0
end
bytes = typecast(md.digest(),'uint8');
digest = upper(reshape(dec2hex(bytes,2).',1,[]));
end
