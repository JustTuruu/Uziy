package mn.uziy.backend.tools;

/** CLI: creates or promotes an ADMIN user. */
public final class MakeAdminCli {

    private MakeAdminCli() {
    }

    public static void main(String[] args) {
        if (args.length != 2) {
            System.err.println("usage: makeAdmin <phone8digits> <password>");
            System.exit(64);
        }
        long id = Bootstrap.makeAdmin(args[0], args[1]);
        System.out.println("ok: admin id=" + id + " phone=" + args[0]);
    }
}
