type LinearIssueInput = {
  title: string;
  description: string;
  labelIds?: string[];
};

export type LinearIssueResult = {
  id: string;
  identifier: string;
  url: string;
};

export class LinearConfigError extends Error {
  constructor(message = "Linear is not configured.") {
    super(message);
    this.name = "LinearConfigError";
  }
}

export async function createLinearIssue(
  input: LinearIssueInput,
  env: Record<string, string | undefined> = process.env,
  fetcher: typeof fetch = fetch,
): Promise<LinearIssueResult | null> {
  const apiKey = env.LINEAR_API_KEY;
  const teamId = env.LINEAR_TEAM_ID;

  if (!apiKey || !teamId) {
    return null;
  }

  const projectId = env.LINEAR_SUPPORT_PROJECT_ID;
  const labels = env.LINEAR_SUPPORT_LABEL_IDS
    ?.split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  const response = await fetcher("https://api.linear.app/graphql", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: apiKey,
    },
    body: JSON.stringify({
      query: `
        mutation BramCreateIssue($input: IssueCreateInput!) {
          issueCreate(input: $input) {
            success
            issue {
              id
              identifier
              url
            }
          }
        }
      `,
      variables: {
        input: {
          teamId,
          projectId,
          title: input.title,
          description: input.description,
          labelIds: input.labelIds ?? labels,
        },
      },
    }),
  });

  if (!response.ok) {
    throw new LinearConfigError("Linear issue creation failed.");
  }

  const payload = (await response.json()) as {
    data?: {
      issueCreate?: {
        success?: boolean;
        issue?: LinearIssueResult;
      };
    };
    errors?: unknown[];
  };

  if (payload.errors?.length || !payload.data?.issueCreate?.success) {
    throw new LinearConfigError("Linear issue creation failed.");
  }

  return payload.data.issueCreate.issue ?? null;
}
