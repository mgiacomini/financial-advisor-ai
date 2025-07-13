# Financial Advisor AI Agent

An AI-powered assistant for financial advisors that integrates Gmail, Google Calendar, and HubSpot CRM to provide intelligent Q&A and task automation.

## Features

- **OAuth Integration**: Secure authentication with Google and HubSpot
- **RAG-powered Q&A**: Search across emails and CRM data using vector embeddings
- **Intelligent Task Automation**: Schedule meetings, create contacts, send emails
- **Proactive Agent**: Acts on ongoing instructions when events occur
- **Real-time Chat Interface**: Built with Phoenix LiveView

## Prerequisites

- Elixir 1.14+
- PostgreSQL with pgvector extension
- Node.js 14+ (for assets)
- Google Cloud Console project with Gmail and Calendar APIs enabled
- HubSpot developer account

## Setup

1. **Clone and install dependencies**
   ```bash
   git clone <repository>
   cd financial_advisor_ai
   mix deps.get
   mix deps.compile
   ```

2. **Install pgvector**
   ```sql
   -- Connect to your PostgreSQL database
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

3. **Set up environment variables**
   ```bash
   export GOOGLE_CLIENT_ID="your-google-client-id"
   export GOOGLE_CLIENT_SECRET="your-google-client-secret"
   export HUBSPOT_CLIENT_ID="your-hubspot-client-id"
   export HUBSPOT_CLIENT_SECRET="your-hubspot-client-secret"
   export OPENAI_API_KEY="your-openai-api-key"
   export GUARDIAN_SECRET_KEY="your-guardian-secret"
   export CLOAK_KEY="your-base64-encoded-32-byte-key"
   ```

4. **Generate encryption key for Cloak**
   ```elixir
   # In iex
   32 |> :crypto.strong_rand_bytes() |> Base.encode64()
   ```

5. **Set up the database**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

6. **Configure OAuth**
   - Google: Add `http://localhost:4000/auth/google/callback` to authorized redirect URIs
   - Add `webshookeng@gmail.com` as a test user in Google Cloud Console
   - HubSpot: Configure OAuth app with appropriate scopes

7. **Start the server**
   ```bash
   mix phx.server
   ```

## Development Workflow

### Adding New Tools

1. Define the tool in `lib/financial_advisor_ai/chat/agent.ex`
2. Implement the execution logic in `execute_tool_call/2`
3. Create necessary worker modules if async processing is needed

### Extending RAG

1. Add new ingestion methods in `lib/financial_advisor_ai/rag/engine.ex`
2. Update the embedding schema if new metadata is needed
3. Implement chunking strategies for different content types

### Adding Webhooks

1. Create webhook endpoints in the router
2. Implement webhook processors in the workers directory
3. Add webhook URL configuration in external services

## Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/financial_advisor_ai/chat/agent_test.exs

# Run with coverage
mix test --cover
```

## Architecture Overview

- **Phoenix/LiveView**: Real-time web interface
- **Oban**: Background job processing
- **pgvector**: Vector similarity search
- **Guardian**: JWT authentication
- **Cloak**: Field-level encryption for OAuth tokens

## Security Considerations

- All OAuth tokens are encrypted at rest
- User data is isolated by user_id
- Rate limiting should be implemented for API endpoints
- Webhook endpoints must verify signatures

## Deployment

1. Build release: `MIX_ENV=prod mix release`
2. Run migrations: `_build/prod/rel/financial_advisor_ai/bin/financial_advisor_ai eval "FinancialAdvisorAI.Release.migrate"`
3. Start application: `_build/prod/rel/financial_advisor_ai/bin/financial_advisor_ai start`

## Next Steps

1. Implement comprehensive error handling
2. Add monitoring and alerting
3. Implement rate limiting
4. Add comprehensive test suite
5. Set up CI/CD pipeline
6. Implement webhook signature verification
7. Add support for more complex multi-step workflows
8. Implement conversation title generation
9. Add user settings and preferences
10. Implement data retention policies