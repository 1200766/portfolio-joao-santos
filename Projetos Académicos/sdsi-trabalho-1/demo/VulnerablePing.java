import java.io.*;
import java.util.Scanner;

/*
 * EXEMPLO INTENCIONALMENTE VULNERÁVEL.
 *
 * Não executar fora de um laboratório descartável e isolado. A concatenação da
 * entrada num comando interpretado por /bin/sh permite injeção de comandos.
 * Consulte SafePing.java para a alternativa que evita a shell.
 */
public class VulnerablePing {
	public static void main(String[] args) {
		Scanner scanner = new Scanner(System.in);
		System.out.println("=== Network Ping Utility ===");
		System.out.print("Enter IP address or hostname to ping:");
		String host = scanner.nextLine();
		try {
// VULNERÁVEL: Executa o comando em um shell,permitindo injeção de comandos
			String command = "ping -c 4 " + host;
			System.out.println("Executing: " + command);
// Usa /bin/sh no Linux/Unix para interpretar o comando
			Process process = Runtime.getRuntime().exec(new String[]{"/bin/sh", "-c", command});
// Para Windows, use: new String[]{"cmd.exe", "/c",command}
// Lê a saída do comando
			BufferedReader reader = new BufferedReader(
				new InputStreamReader(process.getInputStream())
			);
			String line;
			while ((line = reader.readLine()) != null) {
				System.out.println(line);
		}
		// Lê erros, se existirem…
			BufferedReader errorReader = new BufferedReader(
				new InputStreamReader(process.getErrorStream())
);
			while ((line = errorReader.readLine()) != null) {
				System.err.println("Error: " + line);}
			int exitCode = process.waitFor();
			System.out.println("\nCommand exited with code: " +
exitCode);
		} catch (Exception e) {
			System.err.println("Exception: " + e.getMessage());
		}
		scanner.close();
	}
}
