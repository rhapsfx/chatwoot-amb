# Contributing to n8n-nodes-chatwoot-amb

Thank you for considering contributing to this project! We welcome contributions from the community.

## Getting Started

1. **Fork the repository**
2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/n8n-nodes-chatwoot-amb.git
   cd n8n-nodes-chatwoot-amb
   ```

3. **Install dependencies**
   ```bash
   npm install
   ```

4. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Building

```bash
# Build once
npm run build

# Watch mode (auto-rebuild on changes)
npm run dev
```

### Testing

Test your changes in a local n8n instance:

1. Link the package locally:
   ```bash
   npm link
   ```

2. In your n8n installation:
   ```bash
   cd ~/.n8n/custom
   npm link n8n-nodes-chatwoot-amb
   ```

3. Restart n8n and test your nodes

### Code Style

We use ESLint and Prettier for code formatting:

```bash
# Check code style
npm run lint

# Fix code style issues
npm run lintfix

# Format code
npm run format
```

**Important:** All code must pass linting before being merged.

## Adding a New Node

To add a new Chatwoot AMB node:

1. Create a new directory in `nodes/`:
   ```bash
   mkdir nodes/ChatwootAMBYourNode
   ```

2. Create the node file:
   ```typescript
   // nodes/ChatwootAMBYourNode/ChatwootAMBYourNode.node.ts
   import {
     IExecuteFunctions,
     INodeExecutionData,
     INodeType,
     INodeTypeDescription,
     NodeOperationError,
   } from 'n8n-workflow';

   export class ChatwootAMBYourNode implements INodeType {
     description: INodeTypeDescription = {
       displayName: 'Chatwoot AMB Your Node',
       name: 'chatwootAMBYourNode',
       icon: 'file:chatwoot.svg',
       group: ['transform'],
       version: 1,
       subtitle: 'Description',
       description: 'Your node description',
       defaults: {
         name: 'AMB Your Node',
       },
       inputs: ['main'],
       outputs: ['main'],
       credentials: [
         {
           name: 'chatwootBotApi',
           required: true,
         },
       ],
       properties: [
         // Your node parameters here
       ],
     };

     async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
       // Your node logic here
     }
   }
   ```

3. Register the node in `package.json`:
   ```json
   {
     "n8n": {
       "nodes": [
         "dist/nodes/ChatwootAMBYourNode/ChatwootAMBYourNode.node.js"
       ]
     }
   }
   ```

4. Build and test

## Pull Request Guidelines

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] Code passes linting (`npm run lint`)
- [ ] Changes have been tested in a local n8n instance
- [ ] Documentation has been updated if needed
- [ ] Commit messages are clear and descriptive

### PR Description Template

```markdown
## Description
[Brief description of changes]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
[Describe how you tested your changes]

## Screenshots (if applicable)
[Add screenshots of the node UI]

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Changes tested in n8n
- [ ] Documentation updated
```

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

Examples:
```
feat: add Chatwoot AMB Custom App node
fix: correct image encoding in List Picker
docs: update README with installation instructions
```

## Node Design Guidelines

### Parameter Naming

- Use camelCase for parameter names: `summaryText`, `imageUrl`
- Use clear, descriptive names
- Add helpful descriptions and hints

### Error Handling

Always wrap execution logic in try-catch:

```typescript
async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
  const items = this.getInputData();
  const returnData: INodeExecutionData[] = [];

  for (let i = 0; i < items.length; i++) {
    try {
      // Your logic here
    } catch (error) {
      if (this.continueOnFail()) {
        returnData.push({
          json: { error: error.message },
          pairedItem: { item: i },
        });
        continue;
      }
      throw new NodeOperationError(this.getNode(), error);
    }
  }

  return [returnData];
}
```

### UI/UX Best Practices

- Provide sensible defaults
- Add placeholders for complex fields
- Use hints for additional guidance
- Group related parameters using collections
- Use appropriate field types (string, number, boolean, etc.)

## Code Review Process

1. Submit your PR
2. Maintainers will review within 1-2 weeks
3. Address any feedback
4. Once approved, maintainers will merge

## Questions?

- Open an [issue](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/issues)
- Start a [discussion](https://github.com/chatwoot/n8n-nodes-chatwoot-amb/discussions)
- Join the [Chatwoot community](https://chatwoot.com/community)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
