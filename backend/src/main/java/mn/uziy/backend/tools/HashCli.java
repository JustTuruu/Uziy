package mn.uziy.backend.tools;

/** CLI: prints the BCrypt hash of the single argument. */
public final class HashCli {

    private HashCli() {
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("usage: hash <password>");
            System.exit(64);
        }
        System.out.println(Bootstrap.bcrypt(args[0]));
    }
}
