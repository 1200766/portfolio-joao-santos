function errorMessages(error: unknown) {
  const messages: string[] = [];
  let current: unknown = error;

  for (let depth = 0; current && depth < 8; depth += 1) {
    if (current instanceof Error) {
      messages.push(current.message);
    } else if (
      typeof current === "object" &&
      current !== null &&
      "message" in current
    ) {
      messages.push(String(current.message));
    } else {
      messages.push(String(current));
    }

    current =
      typeof current === "object" && current !== null && "cause" in current
        ? current.cause
        : null;
  }

  return messages;
}

export function isDatabaseBusyError(error: unknown) {
  return errorMessages(error).some((message) =>
    /database is locked|SQLITE_BUSY|D1_ERROR.*busy/i.test(message),
  );
}

export function isUniqueConstraintError(error: unknown) {
  return errorMessages(error).some((message) =>
    /unique constraint|constraint failed.*unique|SQLITE_CONSTRAINT_UNIQUE/i.test(
      message,
    ),
  );
}

export async function retryDatabaseBusy<T>(
  operation: () => Promise<T>,
  attempts = 4,
) {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (!isDatabaseBusyError(error) || attempt === attempts - 1) throw error;
      await new Promise((resolve) =>
        setTimeout(resolve, 8 * 2 ** attempt),
      );
    }
  }

  throw lastError;
}
