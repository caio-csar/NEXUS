import test from "node:test";
import assert from "node:assert/strict";
import worker from "../cloudflare/nexus-access-worker.mjs";

const url = "https://exemplo.workers.dev/nexus/access";
const env = { GITHUB_TOKEN: "token-de-teste", GITHUB_REPO: "caio-csar/NEXUS-Logs" };

function requisicao(data, headers = {}) {
  return new Request(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: typeof data === "string" ? data : JSON.stringify(data),
  });
}

const evento = {
  data_hora_cliente: "2026-11-05T15:48:22-03:00",
  usuario_nexus: "tecnico01",
  computador: "PC-SUPORTE",
  usuario_windows: "Suporte",
  sistema_operacional: "Windows NT 10.0.22631.0",
};

test("grava apenas os campos permitidos no GitHub privado", async () => {
  const anterior = globalThis.fetch;
  let recebeu = false;
  globalThis.fetch = async (githubUrl, init) => {
    if (init.method === "GET") {
      assert.equal(githubUrl, "https://api.github.com/repos/caio-csar/NEXUS-Logs");
      return new Response(JSON.stringify({ private: true }), { status: 200 });
    }
    recebeu = true;
    assert.match(githubUrl, /^https:\/\/api\.github\.com\/repos\/caio-csar\/NEXUS-Logs\/contents\/acessos\//);
    assert.equal(init.method, "PUT");
    assert.equal(init.headers.Authorization, "Bearer token-de-teste");
    const body = JSON.parse(init.body);
    const registro = JSON.parse(Buffer.from(body.content, "base64").toString("utf8"));
    assert.equal(registro.usuario_nexus, "tecnico01");
    assert.equal(registro.computador, "PC-SUPORTE");
    assert.equal(registro.evento, "abertura_nexus");
    assert.ok(registro.data_hora_servidor);
    assert.equal(registro.senha, undefined);
    return new Response("{}", { status: 201 });
  };
  try {
    const resposta = await worker.fetch(requisicao({ ...evento, senha: "NAO-PERSISTIR" }), env);
    assert.equal(resposta.status, 204);
    assert.ok(recebeu);
  } finally {
    globalThis.fetch = anterior;
  }
});

test("nao grava payloads invalidos", async () => {
  const anterior = globalThis.fetch;
  globalThis.fetch = async () => { throw Error("Nao deveria acessar o GitHub"); };
  try {
    const resposta = await worker.fetch(requisicao({ ...evento, computador: "" }), env);
    assert.equal(resposta.status, 400);
  } finally {
    globalThis.fetch = anterior;
  }
});

test("rejeita conteudo grande", async () => {
  const resposta = await worker.fetch(requisicao({ ...evento, extra: "x".repeat(2200) }), env);
  assert.equal(resposta.status, 413);
});

test("falha fechada sem credencial configurada no servidor", async () => {
  const resposta = await worker.fetch(requisicao(evento), {});
  assert.equal(resposta.status, 503);
});

test("nao grava se o repositorio esta publico", async () => {
  const anterior = globalThis.fetch;
  let escrita = false;
  globalThis.fetch = async (_url, init) => {
    if (init.method === "GET") {
      return new Response(JSON.stringify({ private: false }), { status: 200 });
    }
    escrita = true;
    return new Response("{}", { status: 201 });
  };
  try {
    const resposta = await worker.fetch(requisicao(evento), env);
    assert.equal(resposta.status, 503);
    assert.equal(escrita, false);
  } finally {
    globalThis.fetch = anterior;
  }
});

test("erro do GitHub nao confirma gravação", async () => {
  const anterior = globalThis.fetch;
  globalThis.fetch = async () => new Response("erro", { status: 403 });
  try {
    const resposta = await worker.fetch(requisicao(evento), env);
    assert.equal(resposta.status, 502);
  } finally {
    globalThis.fetch = anterior;
  }
});

test("nao aceita metodos alternativos", async () => {
  const resposta = await worker.fetch(new Request(url, { method: "GET" }), env);
  assert.equal(resposta.status, 404);
});
