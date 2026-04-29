"""This module provides method to enter various input to the model training."""
import argparse


def arguments() -> str:
    """This function returns arguments."""

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--cover_path",
        default="C:\\Users\\dl\\Desktop\\dataset\\train\\cover",
    )
    parser.add_argument(
        "--stego_path",
        default="C:\\Users\\dl\\Desktop\\dataset\\train\\stego",
    )
    parser.add_argument(
        "--valid_cover_path",
        default="C:\\Users\\dl\\Desktop\\dataset\\valid\\cover",
    )
    parser.add_argument(
        "--valid_stego_path",
        default=(
            "C:\\Users\\dl\\Desktop\\dataset\\valid\\stego"
        ),
    )
    parser.add_argument("--checkpoints_dir", default="./checkpoints/")
    parser.add_argument("--batch_size", type=int, default=10)
    parser.add_argument("--num_epochs", type=int, default=50)
    parser.add_argument("--train_size", type=int, default=20)
    parser.add_argument("--val_size", type=int, default=10)
    parser.add_argument("--lr", type=float, default=0.001)

    opt = parser.parse_args()
    return opt
