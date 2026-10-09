function keys = missing_keys(root)
%MISSING_KEYS Return expected run keys absent from validated shards.

inventory = campaignstore.inspect(root);
expected = string(inventory.manifest.expected_run_keys(:));
keys = expected(~ismember(expected,inventory.run_keys));
end
