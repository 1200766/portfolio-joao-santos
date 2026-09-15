import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.Scanner;
import java.util.regex.Pattern;

public class SafePing {
    private static final Pattern SAFE_HOST =
        Pattern.compile("(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?");

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            System.out.println("=== Safe Network Ping Utility ===");
            System.out.print("Enter an IP address or hostname to ping: ");
            String host = scanner.nextLine().trim();

            if (!SAFE_HOST.matcher(host).matches()) {
                System.err.println("Invalid host format.");
                System.exit(2);
            }

            ProcessBuilder builder = new ProcessBuilder("ping", "-c", "4", host);
            builder.redirectErrorStream(true);
            Process process = builder.start();

            try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream())
            )) {
                String line;
                while ((line = reader.readLine()) != null) {
                    System.out.println(line);
                }
            }

            int exitCode = process.waitFor();
            System.out.println("Ping exited with code: " + exitCode);
        } catch (Exception error) {
            System.err.println("Unable to run ping: " + error.getMessage());
            System.exit(1);
        }
    }
}
