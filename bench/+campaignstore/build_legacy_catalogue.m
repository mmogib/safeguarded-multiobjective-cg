function catalogue = build_legacy_catalogue(resultsRoot,outputPath)
%BUILD_LEGACY_CATALOGUE Inventory legacy result artifacts without moving them.

if ~isfolder(resultsRoot)
    error('campaignstore:MissingResultsRoot', ...
        'Legacy results root does not exist: %s',resultsRoot);
end
resultsRoot = char(string(resultsRoot));
outputPath = char(string(outputPath));
files = dir(fullfile(resultsRoot,'**','*'));
files = files(~[files.isdir]);
fullPaths = strings(numel(files),1);
for k = 1:numel(files)
    fullPaths(k) = string(fullfile(files(k).folder,files(k).name));
end
keep = ~strcmpi(fullPaths,string(outputPath));
files = files(keep);
fullPaths = fullPaths(keep);
n = numel(files);
relativePath = strings(n,1);
fileBytes = zeros(n,1);
sha256 = strings(n,1);
campaign = strings(n,1);
schemaType = strings(n,1);
reader = strings(n,1);
prefix = string([resultsRoot filesep]);
for k = 1:n
    relative = erase(fullPaths(k),prefix);
    relative = replace(relative,"\","/");
    relativePath(k) = relative;
    fileBytes(k) = files(k).bytes;
    sha256(k) = string(campaignstore.file_sha256(fullPaths(k)));
    parts = split(relative,"/");
    if numel(parts) > 1, campaign(k) = parts(1); else, campaign(k) = "(root)"; end
    [schemaType(k),reader(k)] = classify_artifact(fullPaths(k));
end
catalogue = table(relativePath,fileBytes,sha256,campaign,schemaType,reader, ...
    'VariableNames',{'relative_path','file_bytes','sha256','campaign', ...
    'schema_type','reader'});
catalogue = sortrows(catalogue,'relative_path');
campaignstore.write_index_atomic(outputPath,catalogue);
end

function [schema,reader] = classify_artifact(path)
[~,~,extension] = fileparts(path);
extension = lower(extension);
if strcmp(extension,'.csv')
    schema = "derived_csv";
    reader = "MATLAB readtable";
    return
end
if ~strcmp(extension,'.mat')
    schema = "binary_artifact";
    reader = "format-specific external reader";
    return
end
try
    info = whos('-file',path);
catch
    schema = "unreadable_mat";
    reader = "manual recovery required";
    return
end
names = string({info.name});
if all(ismember(["rows" "manifest"],names))
    schema = "run_campaign_v5";
    reader = "MATLAB load variables rows, manifest";
elseif all(ismember(["rows" "manifestSaved"],names))
    schema = "eta_study_checkpoint";
    reader = "MATLAB load variables rows, manifestSaved";
elseif all(ismember(["rows" "cfgSaved"],names))
    schema = "nonlipschitz_checkpoint";
    reader = "MATLAB load variables rows, cfgSaved";
elseif all(ismember(["lineTrials" "blockMetadata"],names))
    schema = "line_trial_block";
    reader = "MATLAB load variables lineTrials, blockMetadata";
elseif any(ismember(["report" "phaseA" "phaseB" "stage0"],names))
    schema = "campaign_report";
    reader = "MATLAB load report variable named in MAT directory";
else
    schema = "legacy_mat";
    reader = "MATLAB load; inspect variables with whos -file";
end
end
