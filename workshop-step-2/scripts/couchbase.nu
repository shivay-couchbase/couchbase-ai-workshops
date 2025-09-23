export def init_data_structure [] {
    let storageconfig  = get_storage_config
    let scope = get_private_scope
    create_bucket_if_not_exist $storageconfig.tmp_bucket
    create_bucket_if_not_exist $storageconfig.shared_bucket
    create_bucket_if_not_exist $storageconfig.private_bucket
    create_scope_if_not_exist $storageconfig.private_bucket $scope
    create_scope_if_not_exist $storageconfig.tmp_bucket $scope
    create_scope_if_not_exist $storageconfig.shared_bucket "public"
    create_collection_if_not_exist $storageconfig.shared_bucket "public" $storageconfig.documentation_collection
    create_collection_if_not_exist $storageconfig.private_bucket $scope $storageconfig.conversation_collection 
}

export def search_documentation [
    query
] {
    let vectorized_query = $query | vector enrich-text 
    vector search documentation vector $question.content.vector.0 | get id | subdoc  get content | select content
}


export def get_storage_config [] {
    let storage_config = {
        "shared_bucket" : ( $env.CASH_SHARED_BUCKET? | default "shared"),
        "private_bucket" :  ( $env.CASH_PRIVATE_BUCKET? | default "private"),
        "tmp_bucket" :  ( $env.CASH_SESSION_BUCKET? | default "sessions"), 
        "conversation_collection" :  ( $env.CASH_CONVERSATION_COLLECTION? | default "conversation"), 
        "documentation_collection" :  ( $env.CASH_DOCUMENTATION_COLLECTION? | default "documentation"), 
    }
    $storage_config
}

export def get_private_scope [] {
  cb-env | get username
}

export def create_collection_if_not_exist [
    bucket,
    scope,
    collection
] {
    if (collections --bucket $bucket  --scope $scope | where collection == $collection | is-empty) {collections create --bucket $bucket --scope $scope $collection; print $"Create Collection ($collection)" } else {print "Collection already exist"}
    create_vector_index_if_not_exist $bucket $scope $collection $collection
}

export def create_scope_if_not_exist [
    bucket,
    scope
] {
    if (scopes --bucket $bucket | where scope == $scope | is-empty) {scopes create --bucket $bucket $scope; print $"Create Scope ($scope)"} else {print "Scope already exist"}
}

export def create_bucket_if_not_exist [
    bucket,
] {
    if (buckets| where name == $bucket | is-empty) {buckets create --replicas 0 $bucket 100; print $"Create Bucket ($bucket)"} else {print "Bucket already exist"}
}

export def create_vector_index_if_not_exist [
    bucket,
    scope,
    collection,
    name
] {
    let indexName = $"($bucket).($scope).($name)"
    if ( ( query indexes | where $it.type == "fts" and $it.bucket? == $bucket  and $it.scope? == $scope and $it.keyspace? == $collection and $it.name? == $indexName ) == [] ) {
        vector create-index --bucket $bucket --scope $scope --collection $collection --similarity-metric dot_product $name vector 1536
    }
}