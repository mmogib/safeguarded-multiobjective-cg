function write_index_atomic(path,index)
%WRITE_INDEX_ATOMIC Internal atomic CSV cache replacement.

folder = fileparts(path);
temporary = [tempname(folder) '.tmp.csv'];
cleanup = onCleanup(@() delete_if_present(temporary));
writetable(index,temporary);
sourceDigest = campaignstore.file_sha256(temporary);
if isfile(path)
    replace_existing(temporary,path,sourceDigest);
else
    install_new(temporary,path,sourceDigest);
end
end

function replace_existing(source,destination,sourceDigest)
% Dropbox reparse points can make forced movefile replacement destructive:
% the destination may be removed before the source move fails.  Keep the
% source intact, copy over the nonauthoritative cache, and verify the bytes.
message = '';
for attempt = 1:5
    try
        [ok,message] = copyfile(source,destination,'f');
        if ok && same_digest(destination,sourceDigest)
            return
        end
    catch cause
        message = cause.message;
    end
    pause(0.05*2^(attempt-1));
end
error('campaignstore:IndexWriteFailed','%s',message);
end

function install_new(source,destination,sourceDigest)
message = '';
for attempt = 1:5
    [ok,message] = movefile(source,destination);
    if ok || same_digest(destination,sourceDigest)
        return
    end
    if ~isfile(source)
        break
    end
    pause(0.05*2^(attempt-1));
end
error('campaignstore:IndexWriteFailed','%s',message);
end

function tf = same_digest(path,expected)
tf = false;
if ~isfile(path), return; end
try
    tf = strcmp(campaignstore.file_sha256(path),expected);
catch
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
