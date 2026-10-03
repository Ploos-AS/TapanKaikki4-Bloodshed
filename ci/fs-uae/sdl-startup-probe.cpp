#include <stdio.h>
#include <SDL/SDL.h>

int main()
{
    FILE* f = fopen("SYS:save/m3-sdl-main.txt", "w");
    if (!f)
        return 20;
    fputs("main\n", f);
    fclose(f);

    if (SDL_Init(SDL_INIT_TIMER) < 0)
        return 21;

    f = fopen("SYS:save/m3-sdl-init.txt", "w");
    if (!f) {
        SDL_Quit();
        return 22;
    }
    fputs("sdl-init-ok\n", f);
    fclose(f);
    SDL_Quit();
    return 0;
}
