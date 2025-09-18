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

## Create a Bucket

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

You can get your API key from the [OpenAI API dashboard](https://platform.openai.com/api-keys).