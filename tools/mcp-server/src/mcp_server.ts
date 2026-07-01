import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  GetPromptRequestSchema,
  ListPromptsRequestSchema,
  ListToolsRequestSchema
} from "@modelcontextprotocol/sdk/types.js";
import { SERVER_INSTRUCTIONS, SERVER_NAME, SERVER_VERSION } from "./config.js";
import { listProjectFiles } from "./file_index.js";
import { getPrompt, listPrompts } from "./prompts.js";
import {
  assetInventory,
  codexTaskBrief,
  gameSystemSummary,
  repoOverview,
  roadmapContext,
  safeReadProjectFiles
} from "./repo_analysis.js";
import { searchProject } from "./search.js";
import { listSafeChecks, runSafeCheck } from "./safe_checks.js";
import { gitContext } from "./git.js";
import { findSymbols } from "./symbols.js";

export type ToolResponse = {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
};

export const TOOL_DEFINITIONS = [
  {
    name: "repo_overview",
    description: "Return a structured summary of repository stack, entrypoints, folders, scripts and documentation status.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false }
  },
  {
    name: "list_project_files",
    description: "List relevant project files filtered by area: gameplay, rendering, biomi, zombie mode, GUI, assets, tests, docs or config.",
    inputSchema: {
      type: "object",
      properties: {
        area: { type: "string", description: "Area filter. Use all, gameplay, rendering, biomi, zombie mode, gui, assets, tests, docs or config." },
        maxResults: { type: "number", description: "Maximum files to return. Capped by the server." },
        includeIgnored: { type: "boolean", description: "Include normally ignored heavy/cache/vendor paths." },
        includeLockfiles: { type: "boolean", description: "Include lockfiles when explicitly needed." }
      },
      additionalProperties: false
    }
  },
  {
    name: "read_project_context",
    description: "Safely read specific text files from inside the repository root. Blocks traversal, binary files and sensitive paths.",
    inputSchema: {
      type: "object",
      properties: {
        paths: { type: "array", items: { type: "string" }, description: "Repo-relative, absolute in-root or res:// paths." },
        maxBytesPerFile: { type: "number", description: "Per-file read limit. Capped by the server." }
      },
      required: ["paths"],
      additionalProperties: false
    }
  },
  {
    name: "search_project",
    description: "Search literal text in safe text files with extension/folder filters, file-size limits and result caps.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string" },
        extensions: { type: "array", items: { type: "string" }, description: "Optional extensions such as .gd or md." },
        directories: { type: "array", items: { type: "string" }, description: "Optional repo-relative directories." },
        caseSensitive: { type: "boolean" },
        maxResults: { type: "number" },
        maxFileBytes: { type: "number" }
      },
      required: ["query"],
      additionalProperties: false
    }
  },
  {
    name: "game_system_summary",
    description: "Summarize main game systems from files that actually exist in the repo, with evidence paths.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false }
  },
  {
    name: "roadmap_context",
    description: "Find and summarize TODO, roadmap, milestones, audit, AGENTS, README and similar planning documents.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false }
  },
  {
    name: "run_safe_check",
    description: "Run only allowlisted safe checks such as GUT, asset check and MCP build/test. Does not run arbitrary shell.",
    inputSchema: {
      type: "object",
      properties: {
        check: { type: "string", description: "Use list to see allowed checks, or one of gut:quick, gut:golden, gut:area, godot:import, asset:check, mcp:build, mcp:test, mcp:smoke." },
        area: { type: "string", description: "Required for gut:area. Allowlisted tests/suites folder name." },
        timeoutMs: { type: "number", description: "Optional timeout, capped by the server." }
      },
      required: ["check"],
      additionalProperties: false
    }
  },
  {
    name: "asset_inventory",
    description: "Inventory available graphics/audio assets by category and report placeholders, duplicate basenames, missing manifest assets and possible unlinked assets.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false }
  },
  {
    name: "codex_task_brief",
    description: "Given a textual goal, produce a Codex implementation brief with likely files, impacted systems, risks, tests and acceptance criteria.",
    inputSchema: {
      type: "object",
      properties: {
        goal: { type: "string", description: "Task objective to prepare." }
      },
      required: ["goal"],
      additionalProperties: false
    }
  },
  {
    name: "git_context",
    description: "Read-only git inspection: working-tree status, recent commit log or diff. Runs only allowlisted git subcommands, never arbitrary shell.",
    inputSchema: {
      type: "object",
      properties: {
        command: { type: "string", description: "One of: status, log, diff." },
        maxCount: { type: "number", description: "log only: number of commits to return. Capped by the server." },
        staged: { type: "boolean", description: "diff only: show staged changes (--cached) instead of the working tree." },
        path: { type: "string", description: "log/diff only: optional repo-relative path to scope the result." }
      },
      required: ["command"],
      additionalProperties: false
    }
  },
  {
    name: "find_symbol",
    description: "Find GDScript declarations (class_name, extends, func, signal, const, enum, inner class) by name across .gd files, with file and line.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Substring or exact name to match. Omit to list all declarations of the given kind." },
        kind: {
          type: "array",
          items: { type: "string" },
          description: "Optional filter: class_name, inner_class, extends, func, signal, const, enum. Defaults to all."
        },
        exact: { type: "boolean", description: "Require an exact name match instead of substring." },
        maxResults: { type: "number", description: "Maximum matches to return. Capped by the server." },
        maxFileBytes: { type: "number", description: "Per-file scan limit. Capped by the server." }
      },
      additionalProperties: false
    }
  }
] as const;

function jsonContent(data: unknown, isError = false): ToolResponse {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(data, null, 2)
      }
    ],
    ...(isError ? { isError: true } : {})
  };
}

export async function callProjectTool(root: string, name: string, args: Record<string, unknown> = {}): Promise<ToolResponse> {
  try {
    switch (name) {
      case "repo_overview":
        return jsonContent(await repoOverview(root));
      case "list_project_files":
        return jsonContent(await listProjectFiles(root, args));
      case "read_project_context":
        return jsonContent(await safeReadProjectFiles(root, args));
      case "search_project":
        return jsonContent(await searchProject(root, args));
      case "game_system_summary":
        return jsonContent(await gameSystemSummary(root));
      case "roadmap_context":
        return jsonContent(await roadmapContext(root));
      case "run_safe_check":
        if (args.check === "list") {
          return jsonContent({ checks: listSafeChecks() });
        }
        return jsonContent(await runSafeCheck(root, args));
      case "asset_inventory":
        return jsonContent(await assetInventory(root));
      case "codex_task_brief":
        return jsonContent(await codexTaskBrief(root, args));
      case "git_context":
        return jsonContent(await gitContext(root, args));
      case "find_symbol":
        return jsonContent(await findSymbols(root, args));
      default:
        return jsonContent({ error: `Unknown tool '${name}'.` }, true);
    }
  } catch (error) {
    return jsonContent({ error: error instanceof Error ? error.message : String(error) }, true);
  }
}

export function createProjectMcpServer(root: string): Server {
  const server = new Server(
    {
      name: SERVER_NAME,
      version: SERVER_VERSION
    },
    {
      capabilities: {
        tools: {},
        prompts: {}
      },
      instructions: SERVER_INSTRUCTIONS
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: TOOL_DEFINITIONS
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const args = (request.params.arguments ?? {}) as Record<string, unknown>;
    return callProjectTool(root, request.params.name, args);
  });

  server.setRequestHandler(ListPromptsRequestSchema, async () => listPrompts());

  server.setRequestHandler(GetPromptRequestSchema, async (request) => {
    const promptArgs = Object.fromEntries(
      Object.entries(request.params.arguments ?? {}).map(([key, value]) => [key, String(value)])
    );
    return getPrompt(request.params.name, promptArgs);
  });

  return server;
}
