# CLAUDE.md - AI Assistant Guide for Harzog-Zeui-Clone

This document provides comprehensive guidance for AI assistants (particularly Claude) working with this codebase. It covers repository structure, development workflows, coding conventions, and best practices.

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Codebase Structure](#codebase-structure)
3. [Development Workflows](#development-workflows)
4. [Coding Conventions](#coding-conventions)
5. [AI Assistant Guidelines](#ai-assistant-guidelines)
6. [Common Tasks](#common-tasks)
7. [Testing Strategy](#testing-strategy)
8. [Deployment](#deployment)

---

## Repository Overview

**Repository Name:** Harzog-Zeui-Clone
**Purpose:** [To be updated as the project develops]
**Tech Stack:** [To be updated as technologies are added]

### Quick Start

```bash
# Clone the repository
git clone <repository-url>

# Navigate to the project directory
cd Harzog-Zeui-Clone

# Install dependencies (when package.json exists)
# npm install / yarn install / pnpm install

# Run the application (when scripts are defined)
# npm start / yarn start
```

---

## Codebase Structure

As the project develops, the following structure is recommended:

```
Harzog-Zeui-Clone/
├── .git/                   # Git version control
├── .github/                # GitHub-specific files (workflows, issue templates)
│   └── workflows/          # CI/CD workflows
├── src/                    # Source code
│   ├── components/         # Reusable components
│   ├── utils/              # Utility functions
│   ├── services/           # Service layer (API calls, business logic)
│   ├── types/              # Type definitions (TypeScript)
│   ├── constants/          # Application constants
│   └── config/             # Configuration files
├── tests/                  # Test files
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── e2e/               # End-to-end tests
├── docs/                   # Documentation
├── scripts/                # Utility scripts
├── public/                 # Static assets (for web projects)
├── .gitignore             # Git ignore rules
├── package.json           # Node.js dependencies and scripts
├── tsconfig.json          # TypeScript configuration
├── README.md              # Project documentation
└── CLAUDE.md              # This file - AI assistant guide
```

### Key Directories

**Currently:** The repository is empty. Update this section as the structure develops.

---

## Development Workflows

### Git Workflow

#### Branching Strategy

- **Main/Master Branch:** Production-ready code
- **Development Branch:** Integration branch for features
- **Feature Branches:** `feature/<feature-name>` or `claude/<session-id>`
- **Bug Fix Branches:** `fix/<bug-description>`
- **Hotfix Branches:** `hotfix/<issue-description>`

#### Branch Naming Conventions for AI Assistants

When Claude creates branches, they should follow this pattern:
```
claude/claude-md-<session-id>
```

This ensures proper authentication and tracking of AI-generated changes.

#### Commit Message Format

Follow the conventional commits specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

**Examples:**
```
feat(auth): add user authentication with JWT

Implement JWT-based authentication system with login and registration endpoints.
Includes middleware for protected routes.

Closes #123
```

```
fix(api): resolve race condition in data fetching

Handle concurrent requests properly by implementing request queuing.
```

### Pull Request Process

1. **Create Feature Branch:** Start from the latest development branch
2. **Make Changes:** Implement features/fixes with clear commits
3. **Test Thoroughly:** Run all tests and ensure they pass
4. **Update Documentation:** Update relevant docs and comments
5. **Create PR:** Use descriptive title and detailed description
6. **Code Review:** Address feedback from reviewers
7. **Merge:** Squash or merge as appropriate

### Code Review Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] New code has appropriate test coverage
- [ ] Documentation is updated
- [ ] No console.log or debugging code remains
- [ ] Security vulnerabilities are addressed
- [ ] Performance implications are considered

---

## Coding Conventions

### General Principles

1. **DRY (Don't Repeat Yourself):** Avoid code duplication
2. **SOLID Principles:** Follow object-oriented design principles
3. **KISS (Keep It Simple, Stupid):** Prefer simple solutions
4. **YAGNI (You Aren't Gonna Need It):** Don't add unnecessary features
5. **Code for Readability:** Code is read more than written

### Naming Conventions

#### Variables and Functions
- Use **camelCase** for variables and functions
- Use descriptive names that explain purpose
- Avoid single-letter variables except in loops or well-known contexts (i, j, k)

```javascript
// Good
const userAuthToken = generateToken(user);
const isUserAuthenticated = checkAuth(token);

// Bad
const uat = genTok(u);
const x = chk(t);
```

#### Classes and Components
- Use **PascalCase** for classes and React components
- Use noun phrases for classes

```javascript
// Good
class UserAuthenticationService {}
const UserProfileCard = () => {};

// Bad
class userauth {}
const profile = () => {};
```

#### Constants
- Use **UPPER_SNAKE_CASE** for constants

```javascript
// Good
const MAX_RETRY_ATTEMPTS = 3;
const API_BASE_URL = 'https://api.example.com';

// Bad
const maxRetry = 3;
const apiUrl = 'https://api.example.com';
```

#### Files and Folders
- Use **kebab-case** for file names (or match project convention)
- Use **PascalCase** for React component files (if that's the convention)

```
user-authentication.service.js
api-client.ts
UserProfileCard.tsx
```

### Code Formatting

- **Indentation:** 2 or 4 spaces (consistent throughout project)
- **Line Length:** Maximum 80-120 characters
- **Semicolons:** Use consistently (or omit consistently)
- **Quotes:** Single or double quotes (be consistent)
- **Trailing Commas:** Use in multi-line arrays/objects for cleaner diffs

### Comments and Documentation

#### When to Comment
- **Complex Logic:** Explain "why" not "what"
- **Public APIs:** Document parameters, return values, and usage
- **Workarounds:** Explain temporary solutions and why they're needed
- **TODOs:** Mark incomplete work with context

```javascript
// Good - Explains why
// Using exponential backoff to handle rate limiting from API
const delay = Math.pow(2, retryCount) * 1000;

// Bad - Explains what (obvious from code)
// Set delay to 2 to the power of retryCount times 1000
const delay = Math.pow(2, retryCount) * 1000;
```

#### JSDoc/TSDoc for Functions

```typescript
/**
 * Authenticates a user with email and password
 *
 * @param email - User's email address
 * @param password - User's password
 * @returns Authentication token if successful
 * @throws {AuthenticationError} If credentials are invalid
 */
async function authenticateUser(email: string, password: string): Promise<string> {
  // Implementation
}
```

### Error Handling

1. **Use Try-Catch:** For async operations and error-prone code
2. **Specific Error Types:** Create custom error classes
3. **Meaningful Messages:** Provide context in error messages
4. **Don't Swallow Errors:** Always log or handle errors appropriately

```javascript
// Good
try {
  const data = await fetchUserData(userId);
  return processData(data);
} catch (error) {
  if (error instanceof NetworkError) {
    logger.error(`Failed to fetch user ${userId}:`, error);
    throw new UserDataError(`Unable to retrieve user data: ${error.message}`);
  }
  throw error;
}

// Bad
try {
  const data = await fetchUserData(userId);
  return processData(data);
} catch (error) {
  // Silent failure
}
```

### Security Best Practices

1. **Input Validation:** Validate and sanitize all user inputs
2. **SQL Injection:** Use parameterized queries
3. **XSS Prevention:** Escape user-generated content
4. **Authentication:** Use secure token-based authentication
5. **Secrets Management:** Never commit secrets; use environment variables
6. **Dependencies:** Regularly update and audit dependencies
7. **HTTPS:** Always use HTTPS in production
8. **CORS:** Configure CORS appropriately

```javascript
// Bad - SQL injection risk
const query = `SELECT * FROM users WHERE id = ${userId}`;

// Good - Parameterized query
const query = 'SELECT * FROM users WHERE id = ?';
db.execute(query, [userId]);
```

---

## AI Assistant Guidelines

### Core Principles for AI Assistants

1. **Understand Before Changing:** Always read relevant code before making modifications
2. **Maintain Consistency:** Follow existing patterns and conventions in the codebase
3. **Test Your Changes:** Ensure code works and doesn't break existing functionality
4. **Document Changes:** Update docs and comments when modifying functionality
5. **Ask for Clarification:** When requirements are unclear, ask the user
6. **Be Security-Conscious:** Watch for common vulnerabilities
7. **Think About Edge Cases:** Consider error conditions and boundary cases

### Before Making Changes

1. **Search for Existing Implementations:** Don't reinvent the wheel
2. **Understand Dependencies:** Check what depends on the code you're changing
3. **Check for Tests:** Look for existing tests that cover the area
4. **Review Recent Changes:** Look at git history for context

### When Writing Code

1. **Follow Existing Patterns:** Match the style of surrounding code
2. **Add Error Handling:** Don't assume happy paths
3. **Write Tests:** Add tests for new functionality
4. **Update Types:** Keep TypeScript types accurate
5. **Clean Up:** Remove debug code and console.logs

### When Reviewing Code

1. **Check for Security Issues:** SQL injection, XSS, authentication flaws
2. **Verify Error Handling:** Ensure errors are caught and handled
3. **Look for Performance Issues:** N+1 queries, unnecessary loops
4. **Check Test Coverage:** Ensure critical paths are tested
5. **Validate Documentation:** Ensure comments and docs are accurate

### Common Pitfalls to Avoid

1. **Overengineering:** Don't add unnecessary complexity
2. **Breaking Changes:** Be careful with public APIs
3. **Ignoring Edge Cases:** Test boundary conditions
4. **Magic Numbers:** Use named constants instead
5. **Tight Coupling:** Keep components loosely coupled
6. **Missing Validation:** Always validate inputs
7. **Assuming Data Exists:** Check for null/undefined

### Using the TodoWrite Tool

For complex tasks, use the TodoWrite tool to track progress:

```javascript
// Example: Breaking down a complex feature
TodoWrite({
  todos: [
    { content: "Research existing authentication system", status: "completed", activeForm: "Researching auth system" },
    { content: "Design new OAuth integration", status: "in_progress", activeForm: "Designing OAuth integration" },
    { content: "Implement OAuth provider", status: "pending", activeForm: "Implementing OAuth provider" },
    { content: "Add tests for OAuth flow", status: "pending", activeForm: "Adding OAuth tests" },
    { content: "Update documentation", status: "pending", activeForm: "Updating documentation" }
  ]
});
```

### File References

When referencing code, always include file path and line number:

```
The authentication logic is in src/services/auth.service.ts:45
```

---

## Common Tasks

### Adding a New Feature

1. **Understand Requirements:** Clarify what needs to be built
2. **Plan Implementation:** Break down into smaller tasks
3. **Create Branch:** `git checkout -b feature/feature-name`
4. **Implement:** Write code following conventions
5. **Test:** Add unit and integration tests
6. **Document:** Update relevant documentation
7. **Commit:** Use conventional commit messages
8. **Push:** Push to remote branch
9. **Create PR:** Open pull request for review

### Fixing a Bug

1. **Reproduce:** Understand and reproduce the bug
2. **Locate:** Find the root cause
3. **Create Branch:** `git checkout -b fix/bug-description`
4. **Fix:** Implement the fix
5. **Test:** Add regression test
6. **Verify:** Ensure bug is fixed and no new issues
7. **Commit:** Describe what was fixed and why
8. **Push and PR:** Create pull request

### Refactoring Code

1. **Ensure Tests Exist:** Have good test coverage before refactoring
2. **Make Small Changes:** Refactor incrementally
3. **Run Tests Frequently:** Ensure nothing breaks
4. **Commit Often:** Small, focused commits
5. **Don't Change Behavior:** Refactoring should not alter functionality

### Adding Dependencies

1. **Evaluate Necessity:** Is the dependency really needed?
2. **Check Security:** Review for known vulnerabilities
3. **Check License:** Ensure compatible license
4. **Check Maintenance:** Is it actively maintained?
5. **Install:** Use package manager (`npm install`, etc.)
6. **Document:** Note why the dependency was added

---

## Testing Strategy

### Testing Pyramid

1. **Unit Tests (70%):** Test individual functions and components
2. **Integration Tests (20%):** Test interactions between components
3. **E2E Tests (10%):** Test complete user workflows

### Unit Testing

```javascript
// Example unit test
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a new user with valid data', async () => {
      const userData = { email: 'test@example.com', password: 'secure123' };
      const user = await UserService.createUser(userData);

      expect(user).toBeDefined();
      expect(user.email).toBe(userData.email);
      expect(user.password).not.toBe(userData.password); // Should be hashed
    });

    it('should throw error for duplicate email', async () => {
      const userData = { email: 'existing@example.com', password: 'secure123' };

      await expect(UserService.createUser(userData))
        .rejects
        .toThrow('Email already exists');
    });
  });
});
```

### Test Coverage Goals

- **Critical Paths:** 100% coverage
- **Business Logic:** 90%+ coverage
- **Utilities:** 80%+ coverage
- **Overall:** 70%+ coverage

### Testing Best Practices

1. **Test Behavior, Not Implementation:** Focus on what, not how
2. **One Assertion Per Test:** Keep tests focused
3. **Descriptive Test Names:** Should explain what is being tested
4. **Arrange-Act-Assert:** Structure tests clearly
5. **Use Mocks Appropriately:** Mock external dependencies
6. **Test Edge Cases:** Include boundary conditions

---

## Deployment

### Environment Variables

Never commit sensitive data. Use environment variables:

```bash
# .env.example (committed to repo)
DATABASE_URL=
API_KEY=
JWT_SECRET=

# .env (NOT committed, in .gitignore)
DATABASE_URL=postgresql://localhost:5432/mydb
API_KEY=real_api_key_here
JWT_SECRET=super_secret_key
```

### Pre-deployment Checklist

- [ ] All tests pass
- [ ] No console.log statements in production code
- [ ] Environment variables are configured
- [ ] Database migrations are applied
- [ ] Documentation is up to date
- [ ] Security scan completed
- [ ] Performance testing done
- [ ] Monitoring and logging configured

### Deployment Process

[To be updated based on deployment strategy]

1. Merge to main/master branch
2. CI/CD pipeline runs tests
3. Build production bundle
4. Deploy to staging environment
5. Run smoke tests
6. Deploy to production
7. Monitor for errors

---

## Additional Resources

### Documentation

- Project README: [README.md](./README.md)
- API Documentation: [To be added]
- Architecture Decisions: [To be added]

### External Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

## Maintaining This Document

This document should be updated as the project evolves:

- **New Patterns:** Document new architectural patterns as they emerge
- **New Tools:** Add sections for new tools and technologies
- **Lessons Learned:** Capture important lessons from development
- **Conventions:** Update coding conventions as they're established

**Last Updated:** 2025-11-16
**Maintainer:** AI Assistants and Development Team

---

## Quick Reference for AI Assistants

### Essential Commands

```bash
# Check project status
git status

# Run tests (when configured)
npm test / yarn test / pnpm test

# Build project (when configured)
npm run build / yarn build / pnpm build

# Lint code (when configured)
npm run lint / yarn lint / pnpm lint

# Format code (when configured)
npm run format / yarn format / pnpm format
```

### Before Every Commit

1. ✅ Code follows style guidelines
2. ✅ Tests pass
3. ✅ No debugging code remains
4. ✅ Documentation updated
5. ✅ Security considerations addressed

### Red Flags to Watch For

- Hardcoded credentials or secrets
- SQL queries built with string concatenation
- Unvalidated user input
- Missing error handling
- Disabled security features
- Large functions (>50 lines - consider refactoring)
- Deep nesting (>3-4 levels)
- Missing tests for critical functionality

---

*This document is a living guide. Improve it as you learn more about the codebase!*
