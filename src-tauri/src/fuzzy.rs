/// Distance between 2 strings.
/// I took this wholesale from https://github.com/wooorm/levenshtein-rs
pub fn levenshtein(a: &str, b: &str) -> usize {
    let mut result = 0;

    /* Shortcut optimizations / degenerate cases. */
    if a == b {
        return result;
    }

    let length_a = a.chars().count();
    let length_b = b.chars().count();

    if length_a == 0 {
        return length_b;
    }

    if length_b == 0 {
        return length_a;
    }

    /* Initialize the vector.
     *
     * This is why it’s fast, normally a matrix is used,
     * here we use a single vector. */
    let mut cache: Vec<usize> = (1..).take(length_a).collect();
    let mut distance_a;
    let mut distance_b;

    /* Loop. */
    for (index_b, code_b) in b.chars().enumerate() {
        result = index_b;
        distance_a = index_b;

        for (index_a, code_a) in a.chars().enumerate() {
            distance_b = if code_a == code_b {
                distance_a
            } else {
                distance_a + 1
            };

            distance_a = cache[index_a];

            result = if distance_a > result {
                if distance_b > result {
                    result + 1
                } else {
                    distance_b
                }
            } else if distance_b > distance_a {
                distance_a + 1
            } else {
                distance_b
            };

            cache[index_a] = result;
        }
    }

    result
}
pub fn score_match(target: &str, query: &str) -> i32 {
    let mut score = 0;

    if target.contains(query) {
        score += 100;
    }

    if target.starts_with(query) {
        score += 50;
    } else if target.ends_with(query) {
        score += 30;
    }

    let distance = levenshtein(query, target);
    score -= distance as i32 * 2; // Assuming lower distance is better, so subtract from score

    let query_lower = query.to_lowercase();
    let target_lower = target.to_lowercase();
    if target_lower.contains(&query_lower) {
        score += 50;
    }
    score
}
