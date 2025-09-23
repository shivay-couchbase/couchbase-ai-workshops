# Vector Search Workshop with Couchbase and Node.js
![Couchbase Capella](https://img.shields.io/badge/Couchbase_Capella-Enabled-red)
[![License: MIT](https://cdn.prod.website-files.com/5e0f1144930a8bc8aace526c/65dd9eb5aaca434fac4f1c34_License-MIT-blue.svg)](/LICENSE)


Welcome to the 2nd part of the workshop. This workshop is designed to help you get started with vector search using Couchbase and Node.js. We will be using the [Couchbase Node.js SDK](https://docs.couchbase.com/nodejs-sdk/current/hello-world/start-using-sdk.html) and [Couchbase Capella](https://www.couchbase.com/products/cloud) managed database service.

The workshop will be run from inside a GitHub Codespace, which is a cloud-based development environment that is pre-configured with all the necessary tools and services. You don't need to install anything on your local machine.

> [!IMPORTANT]
> Key information needed for running this workshop in GitHub Codespaces can be found [here](#running-in-github-codespaces).

## Prerequisites

- A GitHub account
- A Couchbase Capella account

## Workshop Outline

1. [Create a Capella Account](#create-a-capella-account)
2. [Create a Couchbase Cluster](#create-a-couchbase-cluster)
3. [Create a Bucket](#create-a-bucket)
4. [Transform Data](#transform-data)
5. [Index Data](#index-data)
6. [Search Data](#search-data)
7. [Running in GitHub Codespaces](#running-in-github-codespaces)

## Create a Capella Account

Couchbase Capella is a fully managed database service that provides a seamless experience for developers to build modern applications. You can sign up for a free account at [https://cloud.couchbase.com/signup](https://cloud.couchbase.com/signup).

## Create a Couchbase Cluster

Once you have created an account, you can create a new Couchbase cluster by following the steps below:

1. Click on the "Create Cluster" button on the Capella dashboard.

2. Choose a cloud provider, name and region for your cluster and click on the "Create Cluster" button.

## Create an API Key

After creating a cluster, you can create an API Key. This will be used by Couchbase Shell for various cluster management operations.

1. Go to Organization Setting.

2. Click on "API Keys", "Generate Key"

3. Choose a Key Name, enter a description to remember why you created the key, check all Organization Roles and click on "Generate Key".

4. Make sure you copy the API Key and API Secret

## Configure Couchbase Shell

Couchbase Shell is a direct way to interact with your Couchbase Clusters, allowing you to configure, 

1. open `~/.cbsh/config` and edit this file with the following content:

```
version = 1
llms = []

[[capella-organization]]
identifier = "yourOrgIdentifier"
access-key = "yourAccessKey"
secret-key = "yourSecretKey"
default-project = "Trial - Project"

```

2. Run `cbsh` in the terminal to open [Couchbase Shell](https://couchbase.sh).

3. Register your trial cluster by running `clusters | clusters get $in.0.name | cb-env register $in.name $in."connection string" --capella-organization "yourOrgIdentifier" --project "Trial - Project" --save --default-bucket bot --default-scope public --username cbsh --password yourPassword`

4. Verify `~/.cbsh/config` has ben modified. It should contains the cluster definition. From there copy the cluster identifier and run `cb-env cluster clusterIdentifier`. This will tell cbsh that the default cluster for all future operations in this session is your cluster.

5. Create the corresponding credentials `credentials create --read --write --username cbsh --password yourPassword`


## Configure your Cluster

After creating a cluster, you can create a new bucket by following the steps below:

1. Click on the "+ Create" button from inside the cluster dashboard.

2. Define the options for your bucket and click on the "Create" button.

## Ingest Data

### Setting up OpenAI API

This workshop uses OpenAI's embedding API to generate vector embeddings from your JSON documents. You need to set up your OpenAI API key in the environment.

Create a `.env` file in the root directory and add your OpenAI API key:

```bash
OPENAI_API_KEY=your_openai_api_key
```

OpenAI must also be configured for Couchbase Shell, add the following block to `~/.cbsh/config`
```
[[llm]]
identifier = "OpenAI-small"
provider = "OpenAI"
embed_model = "text-embedding-3-small"
chat_model = "gpt-3.5-turbo"
api_key = "get-your-own"
```

You can get your API key from the [OpenAI API dashboard](https://platform.openai.com/api-keys).

### Import Data

Run cbsh and source the `importers.nu` file.
```
source importers.nu
import_markdown_in_folder ../content/files/en-us/glossary/ "glossary "a glossary of IT terms"
let query = "Your question about something in the glossary"
let vectorized_query = $query | vector enrich-text 
let context = vector search documentation vector $question.content.vector.0 | get id | subdoc  get content | select content
$context | ask $question.content.text.0
```
Here the content folder is a local clone of Mozilla Developer network.