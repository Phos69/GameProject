#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { defaultProjectRoot, SERVER_NAME } from "./config.js";
import { createProjectMcpServer } from "./mcp_server.js";

const root = defaultProjectRoot();
// Diagnostics go to stderr; stdout is reserved for the MCP protocol.
console.error(`[${SERVER_NAME}] project root: ${root}`);
const server = createProjectMcpServer(root);
const transport = new StdioServerTransport();

await server.connect(transport);
