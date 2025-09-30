use splitter_md.nu *
use splitter_recursive.nu *
use couchbase.nu *
use embedding.nu *

export def import_markdown_in_folder [
    path,
    name,
    description,
    --visibility: string = "shared"
    --tenant: string = "public"
] {
 let chunked_files = (cd $path; ls **/*.md | each { |f| $f.name | open | markdown-chunker | insert filepath $f.name | insert name $name }) | flatten
 let filtered_chunked_files = $chunked_files | filter { |f|  $f.content | hash sha256 | doc get | get cas | $in.0 == 0  }
 let vectorized_chunked_files = $filtered_chunked_files | chunk_list 8 | each { |file| return ( $file |  vectorize_chunk ) } | flatten 
 let meta = {type : "meta", name : $name, description: $description, count: ($vectorized_chunked_files | length) }
 import_documentation $vectorized_chunked_files $meta --visibility $visibility --tenant $tenant
}

export def import_recursive_in_folder [
    path,
    name,
    description,
    glob,
    --language : string,
    --visibility: string = "shared"
    --tenant: string = "public"
] {
 let chunked_files = ( cd $path; ls ...(glob $glob) | each { |f| $f.name | open | recursive-chunker-from-language --language $language  | insert filepath $f.name | insert language $language }) | flatten 
 let filtered_chunked_files = $chunked_files | filter { |f|  $f.content | hash sha256 | doc get | get cas | $in.0 == 0  }
 let vectorized_chunked_files = $filtered_chunked_files | chunk_list 8 | each { |file| return ( $file |  vectorize_chunk ) } | flatten 
 mut meta = {type : "meta", name : $name, description: $description, count: ($vectorized_chunked_files | length) }
 if ($language != null) { $meta = ( $meta | insert language $language ) }
 import_documentation $vectorized_chunked_files $meta --visibility $visibility --tenant $tenant
}

def import_documentation [
    vectorized_chunked_files,
    meta,
    --visibility: string = "shared",
    --tenant: string = "public",
] {
 let storageconfig  = get_storage_config
 let now = epoch_now_nano
 let meta = $meta | insert date $now
 let filepath = $"($meta.name)-($now).json"
 let metaId = $"meta::($meta.name)"
 let vectorized_chunked_files = $vectorized_chunked_files | each { |c|  ( $c | insert metaId $metaId ) }
 $vectorized_chunked_files | save -f $filepath
 let structure = match $visibility {
    "private" => {bucket: $storageconfig.private_bucket, tenant: get_private_scope }
    _ => {bucket: $storageconfig.shared_bucket, tenant: $tenant }
 }
 create_collection_if_not_exist  $structure.bucket $structure.tenant $storageconfig.documentation_collection
 doc import --bucket $structure.bucket --scope $structure.tenant --collection $storageconfig.documentation_collection --id-column id $filepath
 doc insert --bucket $structure.bucket --scope $structure.tenant --collection $storageconfig.documentation_collection $metaId $meta
}

def vectorize_chunk [
] {
    let strings = $in | reduce --fold [] { | it, acc| ( $acc | append ( $it.content  ) )  }
    let vectors = embed $strings --provider openai
    let vectorized_chunks = $in | enumerate | each { |row| $row.item | insert id ( $row.item.content | hash sha256 ) | insert vector ( $vectors | get ($row.index)  ) }
    $vectorized_chunks
}

def epoch_now_nano [] {
    date now | date to-timezone GMT | into int
}

def chunk_list [
    size
] {
  $in | enumerate | each { |r| update index  ( $r.index // $size ) }| group-by index | values | each { get item }
}
