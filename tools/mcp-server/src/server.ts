#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { defaultProjectRoot } from "./config.js";
import { createProjectMcpServer } from "./mcp_server.js";

const root = defaultProjectRoot();
const server = createProjectMcpServer(root);
const transport = new StdioServerTransport();

await server.connect(transport);
