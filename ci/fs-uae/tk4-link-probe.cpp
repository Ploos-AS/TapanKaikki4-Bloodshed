#include <cstdio>
#include <SDL.h>

#if defined(PROBE_IMAGE)
#include <SDL_image.h>
#endif

#if defined(PROBE_MIXER)
#include <SDL_mixer.h>
#endif

static void mark(const char *path, const char *text)
{
    FILE *f = fopen(path, "w");
    if (f) {
        fputs(text, f);
        fclose(f);
    }
}

int main()
{
    mark("SYS:save/m3-link-main.txt", "main\n");

    if (SDL_Init(SDL_INIT_TIMER) != 0)
        return 10;
    mark("SYS:save/m3-link-sdl.txt", "sdl\n");

#if defined(PROBE_IMAGE)
    const int image_flags = IMG_INIT_PNG | IMG_INIT_JPG;
    const int image_rc = IMG_Init(image_flags);
    if ((image_rc & image_flags) != image_flags)
        return 20;
    mark("SYS:save/m3-link-image.txt", "image\n");
#endif

#if defined(PROBE_MIXER)
    const int mixer_flags = MIX_INIT_OGG | MIX_INIT_MP3;
    (void)Mix_Init(mixer_flags);
    mark("SYS:save/m3-link-mixer.txt", "mixer\n");
#endif

    SDL_Quit();
    return 0;
}
