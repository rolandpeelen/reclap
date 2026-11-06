/*** "Did you mean" suggestions, as clap's `suggestions::did_you_mean`.

clap ranks candidates by Jaro similarity and keeps those above 0.7. */

let threshold = 0.7

let characters = text => text->String.split("")

/** Returns the Jaro similarity of two strings, from 0 (nothing in common) to 1 (equal). */
let jaro = (left, right) => {
  let leftCharacters = characters(left)
  let rightCharacters = characters(right)
  let leftLength = leftCharacters->Array.length
  let rightLength = rightCharacters->Array.length
  switch (leftLength, rightLength) {
  | (0, 0) => 1.
  | (0, _) | (_, 0) => 0.
  | _ =>
    let window = Math.Int.max(0, Math.Int.max(leftLength, rightLength) / 2 - 1)
    // The matching pass needs to remember which characters of `right` are already paired;
    // the flags never leave this function.
    let rightMatched = Array.make(~length=rightLength, false)
    let leftMatches = leftCharacters->Array.filterMapWithIndex((character, leftIndex) => {
      let start = Math.Int.max(0, leftIndex - window)
      let stop = Math.Int.min(rightLength - 1, leftIndex + window)
      let rec findMatch = rightIndex =>
        switch rightIndex > stop {
        | true => None
        | false
          if !(rightMatched->Array.getUnsafe(rightIndex)) &&
          rightCharacters->Array.getUnsafe(rightIndex) == character =>
          rightMatched->Array.setUnsafe(rightIndex, true)
          Some(character)
        | false => findMatch(rightIndex + 1)
        }
      findMatch(start)
    })
    let rightMatches =
      rightCharacters->Array.filterWithIndex((_, rightIndex) =>
        rightMatched->Array.getUnsafe(rightIndex)
      )
    let matchCount = leftMatches->Array.length
    switch matchCount {
    | 0 => 0.
    | _ =>
      let transpositions =
        leftMatches->Array.reduceWithIndex(0, (count, character, index) =>
          rightMatches->Array.getUnsafe(index) == character ? count : count + 1
        ) / 2
      let matches = Int.toFloat(matchCount)
      (matches /. Int.toFloat(leftLength) +.
      matches /. Int.toFloat(rightLength) +.
      (matches -. Int.toFloat(transpositions)) /. matches) /. 3.
    }
  }
}

/** Returns the candidates whose similarity to `input` exceeds 0.7, from the least to the most
similar. Candidates with equal similarity keep their order. */
let didYouMean = (input, candidates) =>
  candidates
  ->Array.map(candidate => (jaro(input, candidate), candidate))
  ->Array.filter(((confidence, _)) => confidence > threshold)
  ->Array.toSorted(((left, _), (right, _)) => Float.compare(left, right))
  ->Array.map(((_, candidate)) => candidate)

/** Returns the single most similar candidate, as clap does for arguments and values. */
let best = (input, candidates) => didYouMean(input, candidates)->Array.last
