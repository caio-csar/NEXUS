// NEXUS - receptor de registros de abertura (Cloudflare Worker).
// O token de acesso ao GitHub deve existir apenas como Secret no Worker.
// Os dados recebidos sao informativos e nao comprovam identidade criptograficamente.

const LIMITE_BYTES = 2048;

function campoTexto(valor, limite) {
  if (typeof valor !== "string") return null;
  const texto = valor.trim();
  if (!texto || texto.length > limite || /[\u0000-\u001f\u007f]/.test(texto)) return null;
  return texto;
}

function resposta(status) {
  return new Response(null, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/nexus/access" || request.method !== "POST") {
      return resposta(404);
    }

    if (!env.GITHUB_TOKEN || !/^[\w.-]+\/[\w.-]+$/.test(env.GITHUB_REPO || "")) {
      return resposta(503);
    }

    const tipo = (request.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
    if (tipo !== "application/json") return resposta(415);

    let conteudo;
    try {
      const texto = await request.text();
      if (new TextEncoder().encode(texto).length > LIMITE_BYTES) return resposta(413);
      conteudo = JSON.parse(texto);
    } catch {
      return resposta(400);
    }

    if (!conteudo || typeof conteudo !== "object" || Array.isArray(conteudo)) {
      return resposta(400);
    }

    const usuario = campoTexto(conteudo.usuario_nexus, 128);
    const computador = campoTexto(conteudo.computador, 128);
    const usuarioWindows = campoTexto(conteudo.usuario_windows, 128);
    const windows = campoTexto(conteudo.sistema_operacional, 128);
    const dataCliente = campoTexto(conteudo.data_hora_cliente, 64);

    if (!usuario || !computador || !usuarioWindows || !windows ||
        !dataCliente || !Number.isFinite(Date.parse(dataCliente))) {
      return resposta(400);
    }

    // So dados explicitamente permitidos entram no arquivo; campos extras sao descartados.
    const dataServidor = new Date().toISOString();
    const registro = {
      evento: "abertura_nexus",
      data_hora_servidor: dataServidor,
      data_hora_cliente: dataCliente,
      usuario_nexus: usuario,
      computador,
      usuario_windows: usuarioWindows,
      sistema_operacional: windows,
    };

    const dia = dataServidor.slice(0, 10);
    const arquivo = `acessos/${dia}/${Date.now()}-${crypto.randomUUID()}.json`;
    const bytes = new TextEncoder().encode(JSON.stringify(registro, null, 2) + "\n");
    const base64 = btoa(Array.from(bytes, (byte) => String.fromCharCode(byte)).join(""));

    let respostaGithub;
    try {
      respostaGithub = await fetch(
        `https://api.github.com/repos/${env.GITHUB_REPO}/contents/${arquivo}`,
        {
          method: "PUT",
          headers: {
            Accept: "application/vnd.github+json",
            Authorization: `Bearer ${env.GITHUB_TOKEN}`,
            "Content-Type": "application/json",
            "User-Agent": "NEXUS-Access-Logger",
            "X-GitHub-Api-Version": "2022-11-28",
          },
          body: JSON.stringify({
            message: "log: abertura NEXUS",
            content: base64,
            branch: env.GITHUB_BRANCH || "main",
          }),
        }
      );
    } catch {
      return resposta(502);
    }

    return resposta(respostaGithub.status === 201 ? 204 : 502);
  },
};
