#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Callbacks {
  int (*on_token)(const char *token_utf8, void *user_ctx);
  void (*on_done)(int32_t status, void *user_ctx);
  void *user_ctx;
} Callbacks;

int32_t mrs_init_engine(void);

int32_t mrs_generate_text(const char *prompt, struct Callbacks cbs);

// Runs the model from the provided model directory path. Returns 0 on success.
int32_t mrs_model_run(const char *model_id, int32_t *out_errno);
