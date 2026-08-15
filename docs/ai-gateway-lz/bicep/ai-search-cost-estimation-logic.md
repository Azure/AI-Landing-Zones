# Azure AI Search Cost Estimation

As Azure AI Search has cost associated with multiple dimensions like service tier, number of units, storage, data transfer and other enabled features like cognitive skills, it is challenging to come up with a simple formula to estimate the cost per request.

This document provides a high-level overview of the cost estimation logic for Azure AI Search. The cost estimation logic is based on the pricing details provided by Microsoft for Azure AI Search.

## Scenario 1: Cost Estimation for Standard S1 Search Service:

- **Service Tier**: Standard S1
- **Number of Units**: 2
- **Region**: East US
- **Duration**: 1 month
- **Semantic Ranker**: 100K requests

Total Cost ~ $590/month 

Assuming you have 100% of all API calls going through APIM, you can estimate the cost by multiplying each service usage percentage per month by the cost of the service.

- **Search-Retail**: 60% * $590 = $354
- **Search-HR**: 40% * $590 = $236