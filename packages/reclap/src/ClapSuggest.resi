/*** "Did you mean" suggestions, scored with Jaro similarity as clap's `suggestions` module
does. Internal to reclap. */

/** Returns the candidates whose similarity to `input` exceeds 0.7, from the least to the most
similar. Candidates with equal similarity keep their order. */
let didYouMean: (string, array<string>) => array<string>

/** Returns the single most similar candidate, as clap does for arguments and values. */
let best: (string, array<string>) => option<string>
