/**
 * Verified against the official ADUSTECH website on 2026-09-19.
 * Source: https://kustwudil.edu.ng/node/226
 *
 * The portal confirms six faculties but does not expose a readable department
 * list on its Academic Programmes page. Keep departments empty until verified.
 */
export const ADUSTECH_SOURCE = {
  universityName: 'Aliko Dangote University of Science and Technology, Wudil',
  formerName: 'Kano University of Science and Technology (KUST), Wudil',
  officialWebsite: 'https://kustwudil.edu.ng',
  academicProgrammesUrl: 'https://kustwudil.edu.ng/node/114',
  sourceUrl: 'https://kustwudil.edu.ng/node/226',
  retrievedOn: '2026-09-19',
} as const;

export const ADUSTECH_FACULTIES = [
  { code: 'FAAT', name: 'Faculty of Agriculture and Agriculture Technology' },
  { code: 'FACMS', name: 'Faculty of Computing and Mathematical Science' },
  { code: 'FAEES', name: 'Faculty of Earth and Environmental Science' },
  { code: 'FAENG', name: 'Faculty of Engineering' },
  { code: 'FASCI', name: 'Faculty of Science' },
  { code: 'FASTE', name: 'Faculty of Science and Technical Education' },
] as const;

export const ADUSTECH_DEPARTMENTS: readonly never[] = [];
