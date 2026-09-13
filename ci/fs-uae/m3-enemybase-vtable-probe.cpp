#include <stdio.h>
#include <stdlib.h>

#ifndef PROBE_VARIANT
#define PROBE_VARIANT 0
#endif

#ifndef PROBE_MARKER
#define PROBE_MARKER "SYS:save/m3-vtable-main.txt"
#endif

#if PROBE_VARIANT == 0
class ProbeEnemy {
public:
    ProbeEnemy() {}
    int Value() const { return 0; }
};
#elif PROBE_VARIANT == 1
class ProbeEnemy {
public:
    ProbeEnemy() {}
    virtual ~ProbeEnemy() {}
    virtual int Value() const { return 0; }
};
#elif PROBE_VARIANT == 2
class ProbeBase {
public:
    virtual ~ProbeBase() {}
    virtual int Value() const = 0;
};
class ProbeEnemy : public ProbeBase {
public:
    ProbeEnemy() {}
    virtual ~ProbeEnemy() {}
    virtual int Value() const { return 0; }
};
#elif PROBE_VARIANT == 3
class ProbeBase {
public:
    virtual ~ProbeBase() = 0;
    virtual int Value() const = 0;
};
ProbeBase::~ProbeBase() {}
class ProbeEnemy : public ProbeBase {
public:
    ProbeEnemy() {}
    virtual ~ProbeEnemy() {}
    virtual int Value() const { return 0; }
};
#elif PROBE_VARIANT == 4
class ProbeBase {
public:
    virtual ~ProbeBase() = 0;
    virtual const char *Name() const = 0;
    virtual int Sprite() const = 0;
    virtual float Speed() const = 0;
    virtual int CurrentWeapon() const = 0;
    virtual int Hostile() const = 0;
    virtual int Energy() const = 0;
    virtual int Reward() const = 0;
    virtual int ExplosionDeath() const = 0;
    virtual int SightDistance() const = 0;
};
ProbeBase::~ProbeBase() {}
class ProbeEnemy : public ProbeBase {
public:
    ProbeEnemy() {}
    virtual ~ProbeEnemy() {}
    virtual const char *Name() const { return NULL; }
    virtual int Sprite() const { return 0; }
    virtual float Speed() const { return 0.0f; }
    virtual int CurrentWeapon() const { return 0; }
    virtual int Hostile() const { return 0; }
    virtual int Energy() const { return 0; }
    virtual int Reward() const { return 0; }
    virtual int ExplosionDeath() const { return 0; }
    virtual int SightDistance() const { return 0; }
};
#else
#error unsupported PROBE_VARIANT
#endif

static void write_marker(void)
{
    FILE *f = fopen(PROBE_MARKER, "w");
    if (f) {
        fputs("MAIN=1\n", f);
        fclose(f);
    }
}

int main(void)
{
    write_marker();
    ProbeEnemy enemy;
    return enemy.Value();
}
