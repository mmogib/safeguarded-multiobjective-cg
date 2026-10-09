function index = rebuild_index(root)
%REBUILD_INDEX Recreate the nonauthoritative checkpoint-index cache.

inventory = campaignstore.inspect(root,true);
index = inventory.blocks;
campaignstore.write_index_atomic(fullfile(root,'checkpoint_index.csv'),index);
end
