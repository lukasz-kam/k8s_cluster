resource "aws_lb" "cluster_alb" {
  name               = "cluster-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "cluster_tg" {
  name        = "cluster-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path     = "/ping"
    protocol = "HTTP"
    port     = 30081
  }
}

resource "aws_lb_target_group_attachment" "master_attachement" {
  target_group_arn = aws_lb_target_group.cluster_tg.arn
  target_id        = aws_instance.k3s_master.id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "worker_targets" {
  for_each = { for idx, inst in aws_instance.k3s_worker : idx => inst.id }

  target_group_arn = aws_lb_target_group.cluster_tg.arn
  target_id        = each.value
  port             = 30080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.cluster_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster_tg.arn
  }
}