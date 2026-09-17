import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const argumentsList = process.argv.slice(2);
const sourceArgument = argumentsList.find((argument) => !argument.startsWith("-"));
const shouldReplace = argumentsList.includes("--replace");
const dryRun = argumentsList.includes("--dry-run");
const wantsHelp = argumentsList.includes("--help") || argumentsList.includes("-h");

if (wantsHelp) {
  console.log(
    "Utilização: node scripts/import-clothes.mjs <pasta-fonte> (--dry-run | --replace)",
  );
  console.log(
    "A pasta-fonte deve conter 'ROUPA Adicionada' e 'Roupa Por Adicionar'.",
  );
  console.log("--dry-run valida a origem sem alterar o catálogo.");
  console.log("--replace confirma a substituição de public/roupa e data/clothes.json.");
  process.exit(0);
}

if (!sourceArgument || shouldReplace === dryRun) {
  console.error(
    "Indica a pasta-fonte e escolhe exatamente uma opção: --dry-run ou --replace.",
  );
  console.error(
    "Executa com --help para consultar a utilização. Nenhum ficheiro foi alterado.",
  );
  process.exit(1);
}

const sourceRoot = resolve(sourceArgument);
const outputRoot = join(projectRoot, "public", "roupa");
const stagingRoot = join(projectRoot, "public", ".roupa-import-tmp");
const dataRoot = join(projectRoot, "data");
const dataPath = join(dataRoot, "clothes.json");
const stagingDataPath = join(dataRoot, ".clothes-import-tmp.json");
const imageExtensions = new Set([".heic", ".jpg", ".jpeg", ".png", ".webp"]);
const sourceGroups = ["ROUPA Adicionada", "Roupa Por Adicionar"];

function slugify(value) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, "-e-")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function naturalSort(left, right) {
  return left.localeCompare(right, "pt", {
    numeric: true,
    sensitivity: "base",
  });
}

function readParameters(folderPath) {
  const rtfPath = join(folderPath, "Parametros.rtf");
  const plainText = execFileSync(
    "textutil",
    ["-convert", "txt", "-stdout", rtfPath],
    { encoding: "utf8" },
  );

  function valueFor(label) {
    const match = plainText.match(
      new RegExp(`${label}[\\t ]*-[\\t ]*([^\\r\\n]*)`, "iu"),
    );

    return (match?.[1] ?? "")
      .replace(/^[⁃•–—-]\s*/u, "")
      .trim();
  }

  return {
    type: valueFor("Tipo de Roupa"),
    brand: valueFor("Marca"),
    size: valueFor("Tamanho"),
    price: valueFor("Preço"),
    condition: valueFor("Estado"),
  };
}

const previousClothes = existsSync(dataPath)
  ? JSON.parse(readFileSync(dataPath, "utf8"))
  : [];
const previousOrder = new Map(
  previousClothes.map((item) => [item.id, item.sortOrder]),
);
let nextSortOrder = previousClothes.reduce(
  (largest, item) => Math.max(largest, item.sortOrder),
  0,
);

const folders = sourceGroups.flatMap((groupName) => {
  const groupPath = join(sourceRoot, groupName);

  if (!existsSync(groupPath)) {
    throw new Error(`Missing source group: ${groupName}`);
  }

  return readdirSync(groupPath, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => ({
      folderName: entry.name,
      folderPath: join(groupPath, entry.name),
      groupName,
    }))
    .sort((left, right) => naturalSort(left.folderName, right.folderName));
});

folders.sort((left, right) => {
  const leftId = slugify(left.folderName.trim());
  const rightId = slugify(right.folderName.trim());
  const leftOrder = previousOrder.get(leftId);
  const rightOrder = previousOrder.get(rightId);

  if (leftOrder != null && rightOrder != null) {
    return leftOrder - rightOrder;
  }
  if (leftOrder != null) return -1;
  if (rightOrder != null) return 1;

  const groupDifference =
    sourceGroups.indexOf(left.groupName) - sourceGroups.indexOf(right.groupName);
  return groupDifference || naturalSort(left.folderName, right.folderName);
});

const seenIds = new Set();
const sourceItems = folders.map(({ folderName, folderPath }) => {
  const name = folderName.trim();
  const slug = slugify(name);

  if (seenIds.has(slug)) {
    throw new Error(`Duplicate clothing folder id: ${slug}`);
  }
  seenIds.add(slug);

  const files = readdirSync(folderPath)
    .filter((fileName) => imageExtensions.has(extname(fileName).toLowerCase()))
    .sort(naturalSort);

  if (files.length === 0) {
    throw new Error(`No photos found in ${folderPath}`);
  }

  if (!existsSync(join(folderPath, "Parametros.rtf"))) {
    throw new Error(`Missing Parametros.rtf in ${folderPath}`);
  }

  return {
    files,
    folderName,
    folderPath,
    metadata: readParameters(folderPath),
    name,
    slug,
  };
});

const expectedPhotoCount = sourceItems.reduce(
  (total, item) => total + item.files.length,
  0,
);

if (dryRun) {
  console.log(
    `Validated ${sourceItems.length} clothes and ${expectedPhotoCount} photos. No files were changed.`,
  );
  process.exit(0);
}

rmSync(stagingRoot, { recursive: true, force: true });
rmSync(stagingDataPath, { force: true });
mkdirSync(stagingRoot, { recursive: true });
mkdirSync(dataRoot, { recursive: true });

const clothes = sourceItems.map(
  ({ files, folderName, folderPath, metadata, name, slug }) => {
    const destination = join(stagingRoot, slug);

    mkdirSync(destination, { recursive: true });

    const photos = files.map((fileName, photoIndex) => {
      const outputName = `${String(photoIndex + 1).padStart(2, "0")}.jpg`;
      const inputPath = join(folderPath, fileName);
      const outputPath = join(destination, outputName);

      execFileSync(
        "sips",
        [
          "--resampleHeightWidthMax",
          "1400",
          "--setProperty",
          "format",
          "jpeg",
          "--setProperty",
          "formatOptions",
          "76",
          inputPath,
          "--out",
          outputPath,
        ],
        { stdio: "ignore" },
      );

      return `/roupa/${slug}/${outputName}`;
    });

    return {
      id: slug,
      sortOrder: previousOrder.get(slug) ?? ++nextSortOrder,
      name,
      folderName,
      ...metadata,
      photos,
    };
  },
);

writeFileSync(
  stagingDataPath,
  `${JSON.stringify(clothes, null, 2)}\n`,
);

rmSync(outputRoot, { recursive: true, force: true });
renameSync(stagingRoot, outputRoot);
renameSync(stagingDataPath, dataPath);

const photoCount = clothes.reduce((total, item) => total + item.photos.length, 0);
const newCount = clothes.filter((item) => !previousOrder.has(item.id)).length;
console.log(
  `Imported ${clothes.length} clothes and ${photoCount} photos (${newCount} new clothes).`,
);
