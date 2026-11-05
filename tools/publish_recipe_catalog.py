"""Publish the reviewed catalog with an administrator's short-lived OAuth token.

Set GOOGLE_OAUTH_ACCESS_TOKEN in your environment before running. No credentials
are saved. This script is intentionally separate from client app startup.
"""
import argparse
import json
import os
from pathlib import Path
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', required=True)
    args = parser.parse_args()
    recipes = json.loads((Path(__file__).parent.parent / 'data' / 'recipes.json').read_text())
    assert 10 <= len(recipes) <= 20
    writes = []
    for recipe in recipes:
        fields = {'name': {'stringValue': recipe['name']}}
        for field in ['ingredients', 'instructions']:
            assert recipe[field] and all(isinstance(item, str) and item.strip() for item in recipe[field])
            fields[field] = {'arrayValue': {'values': [{'stringValue': item} for item in recipe[field]]}}
        writes.append({'update': {
            'name': f"projects/{args.project}/databases/(default)/documents/recipeCatalog/{recipe['id']}",
            'fields': fields,
        }})
    request = urllib.request.Request(
        f'https://firestore.googleapis.com/v1/projects/{args.project}/databases/(default)/documents:commit',
        data=json.dumps({'writes': writes}).encode(),
        headers={'Authorization': f"Bearer {os.environ['GOOGLE_OAUTH_ACCESS_TOKEN']}", 'Content-Type': 'application/json'},
        method='POST',
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        json.load(response)
    print(f'Published {len(recipes)} recipes to {args.project}.')


if __name__ == '__main__':
    main()
