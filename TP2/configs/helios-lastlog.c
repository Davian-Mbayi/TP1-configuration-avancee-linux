#include <unistd.h>
#include <stdlib.h>

int main(void)
{
    char *const env[] = {
        "PATH=/usr/bin:/bin",
        "LANG=C",
        NULL
    };

    execle("/usr/bin/tail", "tail", "-n", "10",
           "/var/log/helios/app.log", (char *)NULL, env);

    return EXIT_FAILURE;
}
