use std::collections::HashSet;

pub fn score_match(target: &str, query: &str) -> i32 {
    if query.len() == 0 {
        return 100;
    }

    let mut score = 0;

    if target.contains(query) {
        score += 100;
    }

    if target.starts_with(query) {
        score += 50;
    } else if target.ends_with(query) {
        score += 30;
    }

    let mut query_index = 0;
    let mut char_set: HashSet<char> = HashSet::new();

    for c in target.chars() {
        // If we reach the end of the query string, it means that the target
        // has all of the query's characters in the correct order.
        if query_index == query.len() {
            score += 50;
            break;
        }
        let q_char_opt = query.chars().nth(query_index);
        match q_char_opt {
            Some(q_char) => {
                if q_char == c {
                    query_index += 1;
                }
            }
            None => (),
        }
    }

    target.chars().for_each(|c| {
        char_set.insert(c);
    });

    query.chars().for_each(|c| {
        if char_set.contains(&c) {
            score += 1;
        }
    });

    let query_lower = query.to_lowercase();
    let target_lower = target.to_lowercase();
    if target_lower.contains(&query_lower) {
        score += 50;
    }
    score
}
