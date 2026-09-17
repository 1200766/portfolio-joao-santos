// Configuração externa adicionada na preparação do arquivo para publicação.
// Não existem credenciais de exemplo nem segredos de recurso.
function requireEnvironment(name: string): string {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Configuração em falta: definir ${name} no ambiente local.`);
  }
  return value;
}

export const mongodbUri = requireEnvironment("MONGODB_URI");
export const jwtSecret = requireEnvironment("JWT_SECRET");
