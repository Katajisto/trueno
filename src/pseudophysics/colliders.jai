Collision_Rect :: struct {
    width  : float;
    height : float;
    position : Vector2;
}

Collision_Circle :: struct {
    radius : float;
    position : Vector2;
}

Collision_Result :: struct {
    hit            : bool;
    collisionDepth : float;
}

check_collision :: (rect: Collision_Rect, circle: Collision_Circle) -> Collision_Result {
    closestX := max(rect.position.x - (rect.width / 2.0), min(circle.position.x, rect.position.x + (rect.width / 2.0)));
    closestY := max(rect.position.y - (rect.height / 2.0), min(circle.position.y, rect.position.y + (rect.height / 2.0)));
    distanceX := circle.position.x - closestX;
    distanceY := circle.position.y - closestY;
    distanceSquared := (distanceX * distanceX) + (distanceY*distanceY);
    radiusSquared := circle.radius * circle.radius;
    return Collision_Result.{
        hit = distanceSquared <= radiusSquared
    };
}
